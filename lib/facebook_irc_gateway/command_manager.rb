require 'i18n'

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

    def register(names, options = {}, &block)
      [names].flatten.each do |name|
        name = name.to_s.downcase
        @command_map[name] ||= []
        @command_map[name] << {:block => block, :options => DEFAULT_OPTIONS.merge(options)}
      end
    end

    def process(channel, message)
      cancel = false
      name, tid, args = message.split(/\s+/, 3)
      tid.downcase! if tid

      commands = @command_map[name] || []
      if not commands.empty?
        id, status = @session.typablemap[tid]
        if status.nil?
          # 残念、さやかちゃんでした！
          channel.notice I18n.t('server.invalid_typablemap')
          cancel = true
        else
          commands.each do |command|
            block = command[:block]
            options = command[:options]
            next if tid.nil? and options[:tid]

            begin
              block.call(
                :id => id,
                :status => status,
                :tid => tid,
                :args => args,
                :channel => channel,
                :session => @session
              )
            rescue Exception => e
              channel.notice e.inspect
              e.backtrace.each do |l|
                channel.notice "\t#{l}"
              end
            end

            cancel = true
          end
        end
      end

      cancel
    end

    private

    def register_builtins
      register :re do |options|
        session, channel, status, args = options.values_at(:session, :channel, :status, :args)
        session.api.status(status['id']).comments(:create, :message => args)
        #channel.notice "re: #{status}"
      end

      register [:like, :fav, :arr] do |options|
        session, channel, id, status = options.values_at(:session, :channel, :id, :status)
        session.api.status(id).likes(:create)
        #channel.notice "like: #{status}"
      end
    end
  end
end

