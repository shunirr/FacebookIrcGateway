require 'rubygems'
require 'net/irc'
require 'sdbm'
require 'tmpdir'
require 'uri'
require 'oauth'
require 'facebook_oauth'
require 'openssl'
require 'open-uri'
require 'ya2yaml'

require 'facebook_irc_gateway/utils'
require 'facebook_irc_gateway/typable_map'

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
USERLIST = 'userlist.yaml'

module FacebookIrcGateway
  class Server < Net::IRC::Server::Session
    def server_name
      'FacebookIrcGateway'
    end
  
    def server_version
      '0.0.0'
    end
  
    def main_channel
      '#facebook'
    end
  
    def initialize(server, socket, logger, opts={})
      super

      begin
        agent = FacebookOAuth::Client.new(
          :application_id     => @opts.app_id,
          :application_secret => @opts.app_secret,
          :callback           => @opts.callback
        )
      rescue Exception => e
        @log.error "#{__FILE__}: #{__LINE__}L"
        @log.error e.inspect
        e.backtrace.each do |l|
          @log.error "\t#{l}"
        end
      end
  
      @me = {}
      begin
        @access_token = agent.authorize(:code => @opts.code)
        @client = FacebookOAuth::Client.new(
          :application_id     => @opts.app_id,
          :application_secret => @opts.app_secret,
          :token              => @access_token.token
        )
  
        me = @client.me.feed['data'][0]
        @me[:id]   = me['from']['id']
        @me[:name] = get_name(:data => me['from'])
      rescue Exception => e
        @log.error "#{__FILE__}: #{__LINE__}L"
        @log.error e.inspect
        e.backtrace.each do |l|
          @log.error "\t#{l}"
        end
      end

      @posts = []
      begin
        @userlist = YAML::load_file(USERLIST)
      rescue Exception => e
        @userlist = {}
      end
    end
  
    def on_user(m)
      super
      post @prefix, JOIN, main_channel
      post server_name, MODE, main_channel, '+o', @prefix.nick

      opts_for_feed = @opts.clone
  
      @real, *@opts = @opts.name || @real.split(/\s+/)
      @opts = @opts.inject({}) {|r,i|
        key, value = i.split('=')
        r.update(key => value)
      }
  
      @timeline = TypableMap.new(6000, true)
      @check_friends_thread = Thread.start do
        # TODO: loop
        begin
          check_friends
        rescue Exception => e
          @log.error "#{__FILE__}: #{__LINE__}L"
          @log.error e.inspect
          e.backtrace.each do |l|
            @log.error "\t#{l}"
          end
        end
      end
  
      @check_news_thread = Thread.start do
        sleep 3
        while true
          begin
            check_news(:opts => opts_for_feed)
          rescue Exception => e
            @log.error "#{__FILE__}: #{__LINE__}L"
            @log.error e.inspect
            e.backtrace.each do |l|
              @log.error "\t#{l}"
            end
          end
          sleep 20
        end
      end
    end
  
    def on_disconnected
      @observer.kill rescue nil
    end
  
    def on_privmsg(m)
      super
      message = m[1]

      command, tid, mes = message.split(' ', 3)
      case command.downcase
      when 'like', 'fav'
        begin
          did, data = @timeline[tid] 
          @client.status(did).likes(:create)

          if data['id'] == did
            mes  = data['message']
            name = get_name(:data => data['from'])
          else
            data['comments']['data'].each do |comment|
              if comment['id'] == did
                mes  = comment['message']
                name = get_name(:data => comment['from'])
              end
            end if data['comments']
          end

          post server_name, NOTICE, main_channel, "like for #{name}: #{mes}"
        rescue Exception => e
          post server_name, NOTICE, main_channel, 'Invalid TypableMap'
        end
      when 're'
        if mes
          begin
            did, data = @timeline[tid] 
            id = @client.status(data['id']).comments(:create, :message => mes)['id']
            tname = get_name(:data => data['from'])
            tmes  = data['message']
            post server_name, NOTICE, main_channel, "#{mes} >> #{tname}: #{tmes}"
            @posts.push [id, mes]
          rescue Exception => e
            post server_name, NOTICE, main_channel, 'Invalid TypableMap'
          end
        end
      else
        case message
        when 'undo'
          id, message = @posts.pop
          @client.send(:_delete, id)
          post server_name, NOTICE, main_channel, "delete: #{message}"
        else
          begin
            id = @client.me.feed(:create, :message => message)['id']
            @posts.push [id, message]
            post server_name, NOTICE, main_channel, "#{message} (#{id})"
          rescue Exception => e
            post server_name, NOTICE, main_channel, 'Fail Update...'
            @log.error "#{__FILE__}: #{__LINE__}L"
            @log.error e.inspect
            e.backtrace.each do |l|
              @log.error "\t#{l}"
            end
          end
        end
      end

      if id
        begin
          db = SDBM.open("#{Dir.tmpdir}/#{@real}_news.db", 0666)
          db[id] = '1'
        rescue Exception => e
          @log.error "#{__FILE__}: #{__LINE__}L"
          @log.error e.inspect
          e.backtrace.each do |l|
            @log.error "\t#{l}"
          end
        ensure
          db.close
        end
      end
    end
  
    def on_ctcp(target, message)
    end
  
    def on_whois(m)
    end
  
    def on_who(m)
    end
  
    def on_join(m)
    end
  
    def on_part(m)
    end
  
    private
    def check_friends
      first = true unless @friends
      @friends ||= []
      friends = []
      @client.me.friends['data'].each do |i|
        id   = i['id']
        name = get_name(:data => i)
        friends << {:id => id, :name => name}
      end

      if first
        @friends = friends
        post server_name, RPL_NAMREPLY, @nick, '=', main_channel, @friends.map{|i| "@#{i[:name]}" }.join(' ')
        post server_name, RPL_ENDOFNAMES, @nick, main_channel, 'End of NAMES list'
      else
        prv_friends = @friends.map {|i| i[:name] }
        now_friends =  friends.map {|i| i[:name] }
  
        (now_friends - prv_friends).each do |join|
          join = "@#{join}"
          post "#{join}!#{join}@#{api_base.host}", JOIN, main_channel
        end
  
        (prv_friends - now_friends).each do |part|
          part = "@#{part}"
          post "#{part}!#{part}@#{api_base.host}", PART, main_channel, ''
        end
        @friends = friends
      end
    end
  
    def check_news(args)
      begin
        db = SDBM.open("#{Dir.tmpdir}/#{@real}_news.db", 0666)
        @client.me.home['data'].reverse.each do |d|
          id          = d['id']
          message     = d['message']
          app_name    = d['application']['name'] if d['application']
          from_id     = d['from']['id']
          name        = get_name(:data => d['from'])
          link        = d['link']
          caption     = d['caption']
          description = d['description']
          comments    = d['comments']['data'] if d['comments']
          likes       = d['likes']['data'] if d['likes']

          message = '' unless message
          name = server_name unless name
  
          unless db.include?(id)
            tid = @timeline.push([id, d])
            db[id] = '1'
  
            tokens = []
            tokens << message

            if caption
              tokens << '/' if not message.empty?
              tokens << caption
            end
  
            if description
              tokens << '/' if not message.empty?
              tokens << description
            end
  
            tokens << "#{Utils.shorten_url(link)}" if link
            tokens << "(#{tid})".irc_colorize(:color => :teal) if tid
  
            if app_name
              tokens << "(via #{app_name})".irc_colorize(:color => :teal)
            else
              tokens << '(via web)'.irc_colorize(:color => :teal)
            end

            # @client.status(id).likes(:create) if @opts.autoliker == true
  
            post name, PRIVMSG, main_channel, tokens.join(' ')
          end
  
          comments.each do |comment|
            cid   = comment['id']
            cname = get_name(:data => comment['from'])
            cmes  = comment['message']
            unless db.include?(cid)
              db[cid] = '1'
              ctid = @timeline.push([cid, d])
              tokens = [cmes, "(#{ctid})".irc_colorize(:color => :teal), '>>', "#{name}:", message]
              post cname, PRIVMSG, main_channel, tokens.join(' ')
            end
          end if comments

          likes.each do |like|
            lid   = "#{id}_like_#{like['id']}"
            lname = get_name(:data => like)
            unless db.include?(lid)
              db[lid] = '1'
              tokens = ['(like)'.irc_colorize(:color => :teal), "#{name}: ", message]
              post lname, PRIVMSG, main_channel, tokens.join(' ')
            end
          end if likes and from_id == @me[:id]
  
        end
      rescue Exception => e
        @log.error "#{__FILE__}: #{__LINE__}L"
        @log.error e.inspect
        e.backtrace.each do |l|
          @log.error "\t#{l}"
        end
      ensure
        db.close rescue nil
      end
    end

    def get_name(options={})
      if options[:data]
        id   = options[:data]['id']
        name = options[:data]['name'].gsub(/\s+/, '')
      else
        id   = options[:id]
        name = options[:name]
      end

      @userlist = {} if @userlist.nil?
      if @userlist[id].nil?
        @userlist[id] = name
        open(USERLIST, 'w') do |f|
          f.puts @userlist.ya2yaml(:syck_compatible => true)
        end
      end

      @userlist[id]
    end

  end
end

