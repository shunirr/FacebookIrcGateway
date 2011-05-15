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
      server = options[:server] || @server.server_name
      channel = options[:channel] || @name
      params = options[:params] || []
      @server.post server, command, channel, *params
    end

    def privmsg(message)
      post 'PRIVMSG', :params => [message]
    end

    def notice(message)
      post 'NOTICE', :params => [message]
    end
    # }}}

    def on_privmsg(message)
      notice message
    end

    def on_topic(topic)
      @topic = topic
      @object = FacebookOAuth::FacebookObject.new(topic, @server.client)
      @object.feed['data'].reverse.each do |item|
        #TODO: いい感じに出力する
        #notice item.to_s
      end
    end
  end
end

