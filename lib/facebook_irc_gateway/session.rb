require 'facebook_irc_gateway/channel'
require 'facebook_irc_gateway/typable_map'
require 'facebook_irc_gateway/command_manager'

module FacebookIrcGateway
  class Session
    attr_reader :server, :api, :me_info, :command_manager
    attr_reader :posts, :typablemap, :channels

    def initialize(server, api, me_info)
      @server = server
      @api = api
      @me_info = me_info
      @command_manager = CommandManager.new
      @posts = []
      @channels = {}
      @typablemap = TypableMap.new(6000, true)

      join @server.main_channel, :type => MainChannel
    end


    def join(name, options = {})
      return if @channels.key? name
      channel = @channels[name] = (options[:type] || Channel).new(@server, self, name)
      channel.on_join if channel
      @server.post @server.prefix, 'JOIN', name
      @server.post @server.server_name, 'MODE', name, '+o', @server.prefix.nick
    end

    def part(name)
      return if not @channels.key? name
      channel = @channels.delete(name)
      channel.on_part if channel
      @server.post @server.prefix, 'PART', name
    end


    def on_join(names)
      names.each do |name|
        join name
      end
    end

    def on_part(names)
      names.each do |name|
        part name
      end
    end

    def on_privmsg(name, message)
      channel = @channels[name]
      channel.on_privmsg(message) if channel
    end

  end
end

