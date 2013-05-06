# coding: utf-8

# Ugly...
require 'openssl'
class OpenSSL::SSL::SSLContext
  if const_defined? :DEFAULT_PARAMS
    const_set(:DEFAULT_PARAMS, remove_const(:DEFAULT_PARAMS).merge({
      :ssl_version => 'SSLv3',
      :verify_mode => OpenSSL::SSL::VERIFY_NONE,
    }))
  end
end

module FacebookIrcGateway
  class Server < Net::IRC::Server::Session

    attr_reader :log, :prefix
    attr_reader :opts # 設定を細かくして session に移すべき
    public :post
  
    def server_name
      'FacebookIrcGateway'
    end
  
    def server_version
      FacebookIrcGateway::VERSION
    end
  
    def main_channel
      '#facebook'
    end

    def shutdown
      EventMachine.stop
      Thread.exit
    end

    def on_connected
      @me = OpenStruct.new
      @sessions = {}
      @posts = []
      @channels = {}

      begin
        I18n.load_path += Dir["lib/facebook_irc_gateway/locale/*.yml"]
        I18n.default_locale = @opts.locale

        @client = FacebookOAuth::Client.new(
          :application_id     => @opts.app_id,
          :application_secret => @opts.app_secret,
          :token              => @opts.access_token
        )

        me = @client.me.info
        @me.id   = me['id']
        # TODO:aliasを適用する
        @me.name = Utils.sanitize_name(me['name'])

        @log.debug "id: #{@me.id}, name: #{@me.name}"
      rescue Exception => e
        error_messages(e)
        shutdown
      end

      ActiveRecord::Base.establish_connection @opts.db
    end

    def on_message(m)
      return if not ''.respond_to? :force_encoding
      enc = 'UTF-8'
      m.prefix.force_encoding(enc)
      m.command.force_encoding(enc)
      m.params.each {|param| param.force_encoding(enc)}
    end
  
    def on_user(m)
      super
      @me_id = 'me' # とりあえず固定
      @sessions[@me_id] = Session.new self, @client
    end
  
    def on_privmsg(m)
      EventMachine.defer do
        name, message = m.params
        session = find_session m
        if session
          begin
            session.on_privmsg name, message
          rescue Exception => e
            error_messages(e)
          end
        end
      end
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

    def check_friends
      first = true unless @friends
      @friends ||= []
      friends = []
      @client.me.friends['data'].each do |i|
        id   = i['id']
        # TODO:aliasを適用する
        name = Utils.sanitize_name(i['name'])
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

    def error_messages(e)
      post server_name, NOTICE, main_channel, Utils.exception_to_message(e)

      @log.error e.inspect
      e.backtrace.each do |l|
        @log.error "\t#{l}"
      end
    end
  end
end

