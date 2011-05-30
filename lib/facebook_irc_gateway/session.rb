
module FacebookIrcGateway
  class Session
    attr_reader :server, :api, :command_manager
    attr_reader :typablemap, :channels, :options, :history

    def initialize(server, api)
      @server = server
      @api = api
      @me = api.me.info
      @command_manager = CommandManager.new(self)
      @typablemap = TypableMap.new(50 * 50, true)
      @channels = {}
      @options = server.opts # とりあえず参照だけでもこっちでもつ
      @history = []

      # join newsfeed
      newsfeed = join @server.main_channel, :type => NewsFeedChannel
      newsfeed.start 'me' if newsfeed
    end

    def me(force = false)
      @me = @api.me.info if @me.nil? or force
      @me
    end

    def join(name, options = {})
      return if @channels.key? name
      channel = @channels[name] = (options[:type] || Channel).new(@server, self, name)
      channel.on_join if channel
      @server.post @server.prefix, 'JOIN', name
      @server.post @server.server_name, 'MODE', name, '+o', @server.prefix.nick
      channel
    end

    def part(name)
      return if not @channels.key? name
      channel = @channels.delete(name)
      channel.on_part if channel
      @server.post @server.prefix, 'PART', name
      channel
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

