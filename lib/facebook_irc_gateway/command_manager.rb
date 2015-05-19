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

    def simple_reply(names, message)
      register names do |options|
        session, channel, object = options.values_at(:session, :channel, :object)
        if object.is_a? Comment
          object = object.parent
        end
        res = session.graph.put_connections(object.id, 'comments', :message => message)
        session.history << {:id => res['id'], :type => :status, :message => message} if res
      end
    end

    def register_builtins
      register :re do |options|
        session, channel, object, args = options.values_at(:session, :channel, :object, :args)
        if object.is_a? Comment
          object = object.parent
        end

        session.defer do
          channel.error_handler do
            res = session.graph.put_connections(object.id, 'comments', :message => args)
            session.history << {:id => res['id'], :type => :status, :message => args} if res
          end
        end

        # とりあえず
        channel.notice "#{args} >> #{object.from.nick}: #{object.message}"
      end

      register [:like, :fav, :arr] do |options|
        session, channel, object = options.values_at(:session, :channel, :object)
        session.graph.put_connections(object.id, 'likes')
        session.history << {:id => object.id, :type => :like, :message => object.message}
        channel.notice "#{I18n.t('server.like_mark')} #{object.from.nick}: #{object.to_s}"
      end

      register :undo, :tid => false do |options|
        session, channel = options.values_at(:session, :channel)
        latest = session.deferred_queue.pop
        if latest
          latest.fail :cancel
          channel.notice "遅延キューの実行をキャンセルしました"
        else
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

            session.graph.delete_object(delete_at)
            channel.notice "#{message} #{latest[:message]}"
          end
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
        session.graph.delete_object("#{object.id}/likes")
        channel.notice "#{I18n.t('server.unlike')} #{object.message}"
      end

      register :full do |options|
        session, channel, object = options.values_at(:session, :channel, :object )
        channel.notice "#{I18n.t('server.full')} #{object.message}"
      end

      register :alias do |options|
        session, channel, object, args = options.values_at(:session, :channel, :object, :args)
        unless args.nil?
          old_name = session.user_filter.get_name( :id => object.from.id, :name => object.from.nick )
          session.user_filter.set_name( :id => object.from.id ,:name => args )
          channel.notice I18n.t 'server.alias', :before => old_name, :after => args
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

        channel.notice I18n.t 'server.comment_invisible', :nick => object.from.nick, :status => val ? I18n.t('server.invisible') : I18n.t('server.visible')
      end

      # そのユーザーからのlikeを全て非表示にする
      register [:like_invisible, :l_i, :li ] do |options|
        session, channel, object  = options.values_at(:session, :channel, :object )

        val = ! session.user_filter.get_invisible( :type => :like, :id => object.from.id)
        session.user_filter.set_invisible :type => :like, :id => object.from.id, :val => val

        channel.notice I18n.t 'server.like_invisible', :nick => object.from.nick, :status => val ? I18n.t('server.invisible') : I18n.t('server.visible')
      end

      # tidで指定したstatusのユーザーとアプリケーションの組み合わせをフィルタする
      register [:app_filter,:af] do |options|
        session, channel, object  = options.values_at(:session, :channel, :object )
        if object.instance_of? Comment
          object = object.parent
        end

        app_id = object.app_id
        if app_id
          if session.user_filter.check_app( :id => object.from.id, :app_id => app_id)
            session.user_filter.remove_app( :id => object.from.id, :app_id => app_id)
            channel.notice I18n.t 'server.app_filter', :nick => object.from.nick, :app_name => object.app_name, :status => I18n.t('server.visible')
          else
            session.user_filter.add_app( :id => object.from.id, :app_id => app_id)
            channel.notice I18n.t 'server.app_filter', :nick => object.from.nick, :app_name => object.app_name, :status => I18n.t('server.invisible')
          end
        else
          channel.notice I18n.t 'server.app_filter_error'
        end
      end

      simple_reply :trp, '（＾－＾）'
      simple_reply :swr, '( ﾟ皿ﾟ)'
      simple_reply :uoo, '┗|┳|┛＜ウオオオォォォ！！！'
      simple_reply :tyr, "ヽ|'◇'|ﾉ"
      simple_reply :tk, '└(･ω･)」'
      simple_reply :hr, 'しゃーなしだな！'
    end
  end
end

