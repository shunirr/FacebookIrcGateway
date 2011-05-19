
module FacebookIrcGateway
  class CommandManager

    DEFAULT_OPTIONS = {
      :tid => true
    }

    def initialize(session = nil)
      @session = session
      @command_map = {}
      register_builtins
    end

    def register(name, options = {}, &block)
      name = name.to_s
      @command_map[name] = [] if @command_map[name].nil?
      @command_map[name] << {:block => block, :options => DEFAULT_OPTIONS.merge(options)}
    end

    def process(channel, message)
      name, tid, args = message.split(/\s+/, 3)
      (@command_map[name] || []).each do |block, options|
        next if tid.nil? and not options[:tid]
        block.call :tid => tid, :args => args, :channel => channel, :session => @session
      end
    end

    private

    def register_builtins
    end

  end
end
