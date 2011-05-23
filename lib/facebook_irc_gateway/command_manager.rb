
module FacebookIrcGateway
  class CommandManager

    DEFAULT_OPTIONS = {
      :tid => true
    }

    def initialize(session)
      @session = session
      @command_map = {}
      register_builtins
    end

    def register(name, options = {}, &block)
      name = name.to_s
      @command_map[name] ||= []
      @command_map[name] << {:block => block, :options => DEFAULT_OPTIONS.merge(options)}
    end

    def process(channel, message)
      cancel = false
      name, tid, args = message.split(/\s+/, 3)

      commands = @command_map[name] || []
      if not commands.empty?
        id, status = @session.typablemap[tid]
        commands.each do |command|
          block = command[:block]
          options = command[:options]
          next if tid.nil? and options[:tid]
          block.call :id => id, :status => status, :tid => tid, :args => args, :channel => channel, :session => @session
          cancel = true
        end
      end

      cancel
    end

    private

    def register_builtins
      register :re do |options|
        p "re: #{options}"
        session = options[:session]
        status = options[:status]
        args = options[:args]
        session.api.status(status['id']).comments(:create, :message => args)
      end
    end

  end
end

