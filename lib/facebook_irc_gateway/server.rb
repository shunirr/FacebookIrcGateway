require 'rubygems'
require 'net/irc'
require 'sdbm'
require 'tmpdir'
require 'uri'
require 'oauth'
require 'facebook_oauth'
require 'openssl'
require 'open-uri'

require 'facebook_irc_gateway/utils'
require 'facebook_irc_gateway/typable_map'

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

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
  
    def initialize(*args)
      super
      
      begin
        agent = FacebookOAuth::Client.new(
          :application_id     => CONFIG['id'],
          :application_secret => CONFIG['secret'],
          :callback           => CONFIG['callback']
        )
      rescue Exception => e
        @log.error "#{__FILE__}: #{__LINE__}L"
        @log.error e.inspect
        e.backtrace.each do |l|
          @log.error "\t#{l}"
        end
      end
  
      # got oauth client code?
      @setup = CONFIG['code'].nil?
  
      if @setup then
        @client = agent
        return
      end
  
      begin
        @access_token = agent.authorize(:code => CONFIG['code'])
        @client = FacebookOAuth::Client.new(
          :application_id     => CONFIG['id'],
          :application_secret => CONFIG['secret'],
          :token              => @access_token.token
        )
  
        @myid = @client.me.feed['data'][0]['from']['id'].to_i
      rescue Exception => e
        @log.error "#{__FILE__}: #{__LINE__}L"
        @log.error e.inspect
        e.backtrace.each do |l|
          @log.error "\t#{l}"
        end
      end
    end
  
    def on_user(m)
      super
      post @prefix, JOIN, main_channel
      post server_name, MODE, main_channel, '+o', @prefix.nick
  
      @real, *@opts = @opts.name || @real.split(/\s+/)
      @opts = @opts.inject({}) {|r,i|
        key, value = i.split('=')
        r.update(key => value)
      }
  
      @timeline = TypableMap.new(1000, true)
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
            check_news
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

      command, params, mes = message.split(' ', 3)
      case command.downcase
      when 'like'
        data = @timeline[params] 
        @client.status(data['id']).likes(:create)
        post server_name, NOTICE, main_channel, "like for #{data['from']['name'].gsub(/\s+/, '')}: #{data['message']}"
      when 're'
        if mes
          data = @timeline[params] 
          id = @client.status(data['id']).comments(:create, :message => mes)['id']
          post server_name, NOTICE, main_channel, "#{mes} >> #{data['from']['name'].gsub(/\s+/, '')}: #{data['message']}"
        end
      else
        begin
          id = @client.me.feed(:create, :message => message)['id']
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
      friends = @client.me.friends['data'].map do |i|
        {
          'name' => i['name'].gsub(/\s+/,''), 
          'id'   => i['id'].to_i
        }
      end
  
      if first
        @friends = friends
        post server_name, RPL_NAMREPLY,   @nick, '=', main_channel, @friends.map{|i| "@#{i['name']}" }.join(' ')
        post server_name, RPL_ENDOFNAMES, @nick, main_channel, 'End of NAMES list'
      else
        prv_friends = @friends.map {|i| i['name'] }
        now_friends =  friends.map {|i| i['name'] }
  
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
  
    def check_news
      begin
        db = SDBM.open("#{Dir.tmpdir}/#{@real}_news.db", 0666)
        @client.me.home['data'].reverse.each do |d|
          id          = d['id']
          message     = d['message']
          app_name    = d['application']['name'] if d['application']
          name        = d['from']['name'].gsub(/\s+/, '')
          link        = d['link']
          caption     = d['caption']
          description = d['description']
          comments    = d['comments']['data'] if d['comments']
          #likes       = d['likes']['data'] if d['likes']
  
          tid = @timeline.push(d)

          message = '' unless message
          name = server_name unless name
  
          unless db.include?(id)
            db[id] = '1'
  
            mes = "#{message} "
            if caption
              if mes != ''
                mes += '/ '
              end
              mes += "#{caption} "
            end
  
            if description
              if mes != ''
                mes += '/ '
              end
              mes += "#{description} "
            end
  
            mes += " #{Utils.shorten_url(link)} " if link
  
            if app_name
              mes += "(#{app_name}) "
            else
              mes += '(web) '
            end

            mes += "(#{tid}) " if tid
  
            post name, PRIVMSG, main_channel, mes
          end
  
          comments.each do |comment|
            cid   = comment['id']
            cname = comment['from']['name'].gsub(/\s+/, '')
            unless db.include?(cid)
              db[cid] = '1'
              post cname, PRIVMSG, main_channel, "#{comment['message']} >> #{name}: #{message}"
            end
          end if comments
  
        end
      rescue Exception => e
        @log.error "#{__FILE__}: #{__LINE__}L"
        @log.error e.inspect
      ensure
        db.close rescue nil
      end
    end
  end
end

