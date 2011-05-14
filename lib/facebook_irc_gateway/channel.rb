require 'facebook_oauth'

module FacebookIrcGateway
  class Channel
    def initialize(server, name)
      @server = server
      @name = name
      #@object = FacebookOAuth::FacebookObject.new(object_id, @server.client)
    end

    def post(command, options = {}, *params)
      server = options[:server] || @server.server_name
      channel = options[:channel] || @name
      params = options[:params] || []
      @server.post server_name, command, channel, *params
    end

    def receiver?(name)
      return @name == name
    end
  end
end

