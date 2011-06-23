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
        object = @session.typablemap[tid]

        if tid and object.nil?
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
                :object => object,
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
        session, channel, object, args = options.values_at(:session, :channel, :object, :args)
        if object.is_a? Comment
          object = object.parent
        end

        res = session.api.status(object.id).comments(:create, :message => args)
        session.history << {:id => res['id'], :type => :status, :message => args} if res
      end

      register [:like, :fav, :arr] do |options|
        session, channel, object = options.values_at(:session, :channel, :object)
        session.api.status(object.id).likes(:create)
        session.history << {:id => object.id, :type => :like, :message => object.message}
        channel.notice "#{I18n.t('server.like_mark')} #{object.from.nick}: #{object.to_s}"
      end

      register :undo, :tid => false do |options|
        session, channel = options.values_at(:session, :channel)
        latest = session.history.pop
        if latest
          case latest[:type]
          when :status
            delete_at = latest[:id]
            message = I18n.t('server.delete')
          when :like
            delete_at = "#{latest[:id]}/likes"
            message = I18n.t('server.unlike')
          else
            raise ArgumentError, 'Invalid history type'
          end

          session.api.send(:_delete, delete_at)
          channel.notice "#{message} #{latest[:message]}"
        end
      end

      register :rres do |options|
        session, channel, object, args = options.values_at(:session, :channel, :object, :args)
        if object.is_a? Comment
          object = object.parent
        end
        unless object.comments.empty?
          channel.notice object.message, :from => object.from.nick

          size = object.comments.size
          begin
            start = size - ((args.nil?) ? size : args.to_i)
          rescue => e
            channel.notice I18n.t('server.invalid_typablemap')
          end

          object.comments[start...size].each do |comment|
            channel.notice comment.message, :from => comment.from.nick
          end
        end
      end

      register :unlike do |options|
        session, channel, object = options.values_at(:session, :channel, :object )
        session.api.send(:_delete, "#{object.id}/likes")
        channel.notice "#{I18n.t('server.unlike')} #{object.message}"
      end

      register :trp do |options|
        session, channel, object = options.values_at(:session, :channel, :object)
        message = '（＾－＾）'
        res = session.api.status(object.id).comments(:create, :message => message)
        session.history << {:id => res['id'], :type => :status, :message => message} if res
      end

      register :swr do |options|
        session, channel, object = options.values_at(:session, :channel, :object)
        message = '( ﾟ皿ﾟ)'
        res = session.api.status(object.id).comments(:create, :message => message)
        session.history << {:id => res['id'], :type => :status, :message => message} if res
      end

      register :uoo do |options|
        session, channel, object = options.values_at(:session, :channel, :object)
        message = '┗|┳|┛＜ウオオオォォォ！！！'
        res = session.api.status(object.id).comments(:create, :message => message)
        session.history << {:id => res['id'], :type => :status, :message => message} if res
      end

      register :hr do |options|
        session, channel, object = options.values_at(:session, :channel, :object)
        if object.is_a? Comment
          object = object.parent
        end
        message = 'しゃーなしだな！' # ま、しゃーなしだな！
        res = session.api.status(object.id).comments(:create, :message => message)
        session.history << {:id => res['id'], :type => :status, :message => message} if res
      end

      register :alias do |options|
        session, channel, object, args = options.values_at(:session, :channel, :object, :args)
        unless args.nil?
          old_name = session.user_filter.get_name( :id => object.from.id, :name => object.from.nick )
          session.user_filter.set_name( :id => object.from.id ,:name => args )
          channel.notice "#{I18n.t('server.alias_0')} #{old_name} #{I18n.t('server.alias_1')} #{args} #{I18n.t('server.alias_2')}"
        end
      end
      
      # そのユーザーのstatusに対してのコメントを全て非表示にする(コメントを対象とした場合はその元status主を対象にする)
      register [:comment_invisible, :c_i, :ci ] do |options|
        session, channel, object  = options.values_at(:session, :channel, :object )
        if object.instance_of? Comment
          object = object.parent
        end
        val = ! session.user_filter.get_invisible( :type => :comment, :id => object.from.id)
        session.user_filter.set_invisible :type => :comment, :id => object.from.id, :val => val

        # TODO:I18n化
        channel.notice "#{object.from.nick}へのコメントを#{ val ? '非表示' : '表示' }にします。"
      end

      # そのユーザーからのlikeを全て非表示にする
      register [:like_invisible, :l_i, :li ] do |options|
        session, channel, object  = options.values_at(:session, :channel, :object )

        val = ! session.user_filter.get_invisible( :type => :like, :id => object.from.id)
        session.user_filter.set_invisible :type => :like, :id => object.from.id, :val => val

        # TODO:I18n化
        channel.notice "#{object.from.nick}からのlikeを#{ val ? '非表示' : '表示' }にします。"
      end

      # tidで指定したstatusのユーザーとアプリケーションの組み合わせをフィルタする
      register [:app_filter,:af] do |options|

      end
    end
  end
end

