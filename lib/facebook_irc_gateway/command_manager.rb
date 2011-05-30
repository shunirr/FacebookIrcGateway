# coding: utf-8
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
        if tid and status.nil?
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
        res = session.api.status(status.id).comments(:create, :message => args)
        session.history << {:id => res['id'], :type => :status, :message => args} if res
      end

      register [:like, :fav, :arr] do |options|
        session, channel, id, status = options.values_at(:session, :channel, :id, :status)
        session.api.status(id).likes(:create)
        session.history << {:id => id, :type => :like, :message => status.message}
        channel.notice "(like) #{status.from.name}: #{status.to_s}"
      end

      register :undo, :tid => false do |options|
        session, channel = options.values_at(:session, :channel)
        latest = session.history.pop
        if latest
          case latest[:type]
          when :status
            session.api.send(:_delete, latest[:id])
            channel.notice "delete at: #{latest[:message]}"
          when :like
            session.api.send(:_delete, "#{latest[:id]}/likes")
            channel.notice "unlike at: #{latest[:message]}"
          end
        end
      end

      register :rres do |options|
        session, channel, status, args = options.values_at(:session, :channel, :status, :args)
        unless status.comments.empty?
          channel.notice status.message, :from => status.from.name

          size = status.comments.size
          begin
            start = size - ((args.nil?) ? size : args.to_i)
          rescue => e
            channel.notice I18n.t('server.invalid_typablemap')
          end

          status.comments[start...size].each do |comment|
            channel.notice comment.message, :from => comment.from.name
          end
        end
      end

      register :unlike do |options|
        session, channel, status, id = options.values_at(:session, :channel, :status, :id)
        session.api.send(:_delete, "#{id}/likes")
        channel.notice "unlike at: #{status.message}"
      end

      register :hr do |options|
        session, channel, status = options.values_at(:session, :channel, :status)
        message = 'しゃーなしだな！' # ま、しゃーなしだな！
        res = session.api.status(status.id).comments(:create, :message => message)
        session.history << {:id => res['id'], :type => :status, :message => message} if res
      end

      register :alias, :tid => false do |options|
        session, channel = options.values_at(:session, :channel)
        channel.notice "Unsupported Command"
      end
    end
  end
end

