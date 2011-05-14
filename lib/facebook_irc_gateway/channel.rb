require 'facebook_oauth'

module FacebookIrcGateway
  class Channel
    def initialize(server, name)
      @server = server
      @name = name
      #@object = FacebookOAuth::FacebookObject.new(object_id, @server.client)
    end

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

    def on_privmsg(m)
      @server.log.debug m.params[1]
      notice m.params[1]
    end
  end
end

