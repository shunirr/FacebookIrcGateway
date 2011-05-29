#coding:utf-8
require 'rubygems'
require 'uri'
require 'oauth'
require 'openssl'
require 'open-uri'
require 'yaml'
require 'i18n'

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

module FacebookIrcGateway
  class Server < Net::IRC::Server::Session

    attr_reader :log, :prefix
    attr_reader :opts # 設定を細かくして session に移すべき
    public :post
  
    def server_name
      'FacebookIrcGateway'
    end
  
    def server_version
      '0.0.1'
    end
  
    def main_channel
      '#facebook'
    end
    
    def initialize(server, socket, logger, opts={})
      super

      begin
        p @opts.callback
        
        I18n.load_path += Dir["lib/facebook_irc_gateway/locale/*.yml"]
        I18n.default_locale = @opts.locale
        
        agent = FacebookOAuth::Client.new(
          :application_id     => @opts.app_id,
          :application_secret => @opts.app_secret,
          :callback           => @opts.callback
        )
      rescue Exception => e
        error_messages(e)
      end
  
      @me = {}
      begin
        @access_token = agent.authorize(:code => @opts.code)
        @client = FacebookOAuth::Client.new(
          :application_id     => @opts.app_id,
          :application_secret => @opts.app_secret,
          :token              => @access_token.token
        )
  
        me = @client.me.info
        @me[:id]   = me['id']
        @me[:name] = get_name(:data => me)
      rescue Exception => e
        error_messages(e)
      end

      ActiveRecord::Base.establish_connection(
        :adapter  => @opts.db['adapter'],
        :database => @opts.db['database']
      )

      @sessions = {}
      @posts = []
      @channels = {}
      @duplications = Duplication.objects @me[:id]
    end
  
    def on_user(m)
      super
      @me_id = 'me' # とりあえず固定
      @sessions[@me_id] = Session.new self, @client
    end
  
    def on_disconnected
      @observer.kill rescue nil
    end
  
    def on_privmsg(m)
      name, message = m.params
      session = find_session m
      Thread.start do
        begin
          session.on_privmsg name, message
        rescue Exception => e
          error_messages(e)
        end
      end if session
    end
  
    def on_ctcp(target, message)
    end
  
    def on_whois(m)
    end
  
    def on_who(m)
    end

    def on_topic(m)
      name, topic, = m.params
      session = find_session m
      session.on_topic names if session
    end
  
    def on_join(m)
      names = m.params[0].split(/\s*,\s*/)
      session = find_session m
      session.on_join names if session
    end
  
    def on_part(m)
      names = m.params[0].split(/\s*,\s*/)
      session = find_session m
      session.on_part names if session
    end

    private
    def find_session(m)
      # TODO: ユーザ名でセッションを切り替えたりする
      @sessions[@me_id]
    end

    def process_privmsg m
        name = m[0]
        message = m[1]

        command, tid, mes = message.split(' ', 3)
        tid.downcase! if tid
        case command.downcase
        when 'like', 'fav', 'arr'
          like tid
        when 'alias'
          process_alias tid, mes
        when 'unlike'
          unlike tid
        when 're'
          reply tid, mes
        when 'rres'
          rres tid, mes
        when 'hr'
          haruna tid
        else
          case message
          when 'undo'
            undo
          else
            update_status message, name
          end
        end
    end

    def process_alias tid, mes
      if mes
        begin
          did, data = @timeline[tid]
          if data.id == did
            old_name = get_name(:id => data.from.id, :name => data.from.name)
            set_name(:id => data.from.id, :name => mes)
          else
            data.comments.each do |comment|
              if comment.id == did
                old_name = get_name(:id => comment.from.id, :name => comment.from.name)
                set_name(:id => comment.from.id, :name => mes)
              end
            end
          end

          post server_name, NOTICE, main_channel, "#{I18n.t('server.alias_0')} #{old_name} #{I18n.t('server.alias_1')} #{mes} #{I18n.t('server.alias_2')}"

        rescue Exception => e
          post server_name, NOTICE, main_channel, I18n.t('server.invalid_typablemap')
          error_messages(e)
        end
      end
    end

    def rres tid, count
      did, data = @timeline[tid] 
      return if data.comments.empty?

      begin
        name = get_name(:id => data.from.id, :name => data.from.name)
        post name, NOTICE, main_channel, data.message
  
        comments = data.comments
        comments = comments[(comments.size - count.to_i) .. comments.size] unless count.nil?
  
        comments.each do |comment|
          cname = get_name(:id => comment.from.id, :name => comment.from.name)
          post cname, NOTICE, main_channel, comment.message
        end if comments
      rescue Exception => e
        post server_name, NOTICE, main_channel, I18n.t('server.invalid_typablemap')
        error_messages(e)
      end
    end

    def like tid
      did, data = @timeline[tid] 
      @client.status(did).likes(:create)

      if data.id == did
        mes  = data.message
        name = get_name(:id => data.from.id, :name => data.from.name)
      else
        data.comments.each do |comment|
          if comment.id == did
            mes  = comment.message
            name = get_name(:id => comment.from.id, :name => comment.from.name)
          end
        end
      end

      post server_name, NOTICE, main_channel, "#{I18n.t('server.like')} #{name}: #{mes}"
    rescue Exception => e
      post server_name, NOTICE, main_channel, I18n.t('server.invalid_typablemap')
      error_messages(e)
    end

    def unlike tid
      did, data = @timeline[tid] 
      @client.send(:_delete, "#{did}/likes")

      if data.id == did
        mes  = data.message
        name = get_name(:id => data.from.id, :name => data.from.name)
      else
        data.comments.each do |comment|
          if comment.id == did
            mes  = comment.message
            name = get_name(:id => comment.from.id, :name => comment.from.name)
          end
        end
      end

      post server_name, NOTICE, main_channel, "#{I18n.t('server.unlike')} #{name}: #{mes}"
    rescue Exception => e
      post server_name, NOTICE, main_channel, I18n.t('server.invalid_typablemap')
      error_messages(e)
    end

    def reply tid, mes
      if mes
        begin
          did, data = @timeline[tid] 
          id = @client.status(data.id).comments(:create, :message => mes)['id']
          @posts.push [id, mes]
        rescue Exception => e
          post server_name, NOTICE, main_channel, I18n.t('server.invalid_typablemap')
          error_messages(e)
        end
      end
    end

    def haruna tid
      mes = 'しゃーなしだな！'
      begin
        did, data = @timeline[tid] 
        id = @client.status(data.id).comments(:create, :message => mes)['id']
        @posts.push [id, mes]
      rescue Exception => e
        post server_name, NOTICE, main_channel, mes
        error_messages(e)
      end
    end

    def undo
      id, message = @posts.pop
      @client.send(:_delete, id)
      post server_name, NOTICE, main_channel, "#{I18n.t('server.delete')}: #{message}"
    end

    def update_status message, name
      if name == main_channel
        message += @opts.suffix
        id = @client.me.feed(:create, :message => message)['id']
        @posts.push [id, message]
      else
        session = @sessions[@me_id]
        session.on_privmsg name, message if session
      end
    rescue Exception => e
      post server_name, NOTICE, main_channel, I18n.t('server.fail_update')
      error_messages(e)
    end

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
  
    def check_news
      begin
        feeds = Feeds.new(@client.me.home)
        feeds.each do |feed|
          @duplications.find_or_create_by_object_id feed.id do
            tid = @timeline.push([feed.id, feed])

            @client.status(feed.id).likes(:create) if @opts.autoliker == true

            mode = PRIVMSG
            mode = NOTICE if feed.from.id == @me[:id]
            name = get_name(:name => feed.from.name, :id => feed.from.id)

            post name, mode, main_channel, feed.to_s(:tid => tid, :color => @opts.color)
          end

          feed.comments.each do |comment|
            @duplications.find_or_create_by_object_id comment.id do
              ctid = @timeline.push([comment.id, feed])
              cmode = PRIVMSG
              cmode = NOTICE if comment.from.id == @me[:id]
              cname = get_name(:name => comment.from.name, :id => comment.from.id)
              post cname, cmode, main_channel, comment.to_s(:tid => ctid, :color => @opts.color)
            end
          end

          feed.likes.each do |like|
            @duplications.find_or_create_by_object_id like.from.id do
              lname = get_name(:name => like.from.name, :id => like.from.id)
              post lname, NOTICE, main_channel, like.to_s(:color => @opts.color)
            end
          end if feed.from.id == @me[:id]
        end
      rescue Exception => e
        error_messages(e)
      end
    end

    def get_name(options={})
      if options[:data]
        id   = options[:data]['id']
        name = options[:data]['name'].gsub(/\s+/, '')
      else
        id   = options[:id]
        name = options[:name].gsub(/\s+/, '')
      end

      if @userlist.nil?
        begin
          @userlist = YAML::load_file(@opts.userlist) || {}
        rescue Exception => e
          @userlist = {}
        end
      end

      if @userlist[id].nil?
        set_name(:id => id, :name => name )
      elsif @userlist[id]['enable']
        name = @userlist[id]['name'] if @userlist[id]['name']
      end

      name
    end

    def set_name(options={})
      id   = options[:id]
      name = options[:name].gsub(/\s+/, '')

      if @userlist.nil?
        begin
          @userlist = YAML::load_file(@opts.userlist)
        rescue Exception => e
          @userlist = {}
        end
      end

      if @userlist[id].nil?
        @userlist[id] = {'name' => name, 'enable' => false}
      else
        @userlist[id]['name'] = name
        @userlist[id]['enable'] = true
      end

      open(@opts.userlist, 'w') do |f|
        f.puts @userlist.fig_ya2yaml(:syck_compatible => true)
      end
    end
    
    def error_messages(e)
      error_notice(e)
      @log.error e.inspect
      e.backtrace.each do |l|
        @log.error "\t#{l}"
      end
    end
    
    def error_notice(e)
      case e
      when OAuth2::HTTPError
        post server_name, NOTICE, main_channel, I18n.t('error.oauth2_http')
      when NoMethodError
        if e.to_s =~ /undefined\smethod\s.me.\sfor\snil:NilClass/
          post server_name, NOTICE, main_channel, I18n.t('error.no_method_me')
        end
      when SocketError
        post server_name, NOTICE, main_channel, I18n.t('error.socket')
      end
    end
  end
end

