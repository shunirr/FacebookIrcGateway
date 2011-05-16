require 'facebook_oauth'

module FacebookIrcGateway
  class Channel
    def initialize(server, name)
      @server = server
      @name = name
      @topic = nil
      @object = nil
    end

    # Helpers {{{1
    def post(command, options = {})
      from = options[:from] || @server.server_name
      channel = options[:channel] || @name
      params = options[:params] || []
      @server.post from, command, channel, *params
    end

    def privmsg(message, options = {})
      post 'PRIVMSG', options.merge(:params => [message])
    end

    def notice(message, options = {})
      post 'NOTICE', options.merge(:params => [message])
    end
    # }}}

    def on_privmsg(message)
      #notice message
      if @object
        item = @object.feed(:create, :message => message)
        @server.log.debug item.to_s
      end
    end

    def on_topic(topic)
      @topic = topic
      @object = FacebookOAuth::FacebookObject.new(topic, @server.client)

      if @check_feeds_thread
        @check_feeds_thread.exit
        @check_feeds_thread.join
        @check_feeds_thread = nil
      end
      @check_feeds_thread = async do
        check_feed
      end
    end

    private

    def async(options = {})
      @server.log.debug "begin: async"
      count = options[:count] || 0
      interval = options[:interval] || 30

      return Thread.start do
        loop do
          if count > 0
            count -= 1
            break if count == 0
          end

          begin
            yield
          rescue Exception => e
            @server.log.error "#{__FILE__}: #{__LINE__}L"
            @server.log.error e.inspect
            e.backtrace.each do |l|
              @server.log.error "\t#{l}"
            end
          end

          sleep interval
        end
        @server.log.debug "end: async"
      end
    end

    def check_feed
      @server.log.debug "begin: check_feed"
      @object.feed['data'].reverse.each do |item|
        #TODO: いい感じに出力する
        #notice item.to_s
        name = item["from"]["name"].gsub(/\s+/, '')
        message = item["message"]
        privmsg message, :from => name
      end
      @server.log.debug "end: check_feed"
    end
  end
end

