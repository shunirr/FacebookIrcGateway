
module FacebookIrcGateway
  class Session
    attr_reader :server, :api, :command_manager, :user_filter
    attr_reader :typablemap, :channels, :options, :history

    def initialize(server, api)
      @server = server
      @api = api
      @me = api.me.info
      @channels = {}
      @command_manager = CommandManager.new(self)
      @typablemap = TypableMap.new(50 * 50, true)
      @user_filter = UserFilters.new(@me['id'])
      @options = server.opts # とりあえず参照だけでもこっちでもつ
      @history = []

      # join channels
      Model::Channel.where(:uid => @me['id']).each do |channel|
        join channel.name, :mode => channel.mode, :oid => channel.oid
      end

      # join newsfeed
      join @server.main_channel, :type => NewsFeedChannel, :oid => 'me'
    end

    def me(force = false)
      @me = @api.me.info if @me.nil? or force
      return @me
    end

    def join(name, options = {})
      return @channels[name] if @channels.key? name

      type = options[:type] || Channel
      mode = options[:mode] || '+o'
      oid = options[:oid]

      channel = @channels[name] = type.new(@server, self, name, oid)
      channel.on_join
      channel.start oid if oid

      @server.post @server.prefix, 'JOIN', name
      @server.post @server.server_name, 'MODE', name, mode, @server.prefix.nick

      return channel
    end

    def part(name)
      return nil if not @channels.key? name

      channel = @channels.delete(name)
      channel.on_part

      @server.post @server.prefix, 'PART', name

      return channel
    end


    def on_join(names)
      names.each do |name|
        channel = join name
        channel.save if channel
      end
    end

    def on_part(names)
      names.each do |name|
        channel = part name
        channel.destroy if channel
      end
    end

    def on_privmsg(name, message)
      channel = @channels[name]
      channel.on_privmsg(message) if channel
    end

  end
end

