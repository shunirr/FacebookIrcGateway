
# cm = CommandMatcher.new
# 
# cm.register 're' do |message|
#   tid, mes = message.split(' ')
#   puts mes
# end
#
# cm.run 're', message'

module FacebookIrcGateway
  class CommandManager
    def initialize
      @command_map = {}
    end

    def register(name, &block)
      @command_map[name] = [] if @command_map[name].nil?
      @command_map[name] << block
    end

    def call(name, message)
      commands = @command_map[name]
      if commands
        commands.each do |command|
          command.call message
        end
      end
    end
  end
end

