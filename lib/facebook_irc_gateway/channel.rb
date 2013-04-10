# coding: utf-8

module FacebookIrcGateway
  class Channel

    OBJECTS = [
      'friends',
      'likes',
      'movies',
      'music',
      'books',
      'notes',
      'photos',
      'albums',
      'videos',
      'events',
      'groups',
      'checkins'
    ]

    attr_reader :server, :session, :name, :mode, :object

    def initialize(server, session, name, oid = nil)
      @server = server
      @session = session
      @name = name
      @mode = nil
      @oid = oid
      @object = nil
    end

    # IRC methods {{{1
    def send_irc_command(command, options = {})
      from = Utils.sanitize_name(options[:from] || @server.server_name)
      channel = options[:channel] || @name
      params = options[:params] || []
      @server.post from, command, channel, *params
    end

    def privmsg(message, options = {})
      send_irc_command 'PRIVMSG', options.merge(:params => [message])
    end

    def notice(message, options = {})
      send_irc_command 'NOTICE', options.merge(:params => [message])
    end
    #}}}

    # Events {{{1
    def on_privmsg(message)
      # check command
      return if process_command message
      return if @session.command_manager.process self, message
      if has_object?
        status = update message
      end
    end

    def on_join
    end

    def on_part
      stop
    end

    def on_topic(topic)
      #start topic
    end
    # }}}

    # Record {{{1
    def save
      Model::Channel.where(:uid => @session.me['id']).find_or_initialize_by_name(@name).update_attributes({
        :mode => @mode,
        :oid => @oid
      })
    end

    def destroy
      Model::Channel.where(:uid => @session.me['id'], :name => @name).destroy_all
    end
    # }}}1

    def has_object?
      not @object.nil?
    end

    def object_name(item)
      item.inject([]) do |result, (key, value)|
        result << value if ['name', 'category'].include? key; result
      end.join(' / ')
    end
    # }}}

    def start(oid)
      @oid = oid
      @object = FacebookOAuth::FacebookObject.new(@oid, @session.api)

      notice "start: #{object_name @object.info} (#{@oid})"

      stop
      @check_feed_timer = async do
        check_feed
      end
    end

    def stop
      if @check_feed_timer
        @check_feed_timer.cancel
        @check_feed_timer = nil
      end
    end

    def feed
      Feed.new(@object.feed, @session.user_filter)
    end

    def update(message)
      @session.defer do
        begin
          status = @object.feed(:create, :message => message)
          @session.history << {:id => status['id'], :type => :status, :message => message} if status
        rescue => e
          send_error_message e
        end
      end
    end

    private

    UNWATCHED_ERRORS = [
      SystemCallError,
      Faraday::Error::ClientError
    ]

    def send_error_message(e)
      unless UNWATCHED_ERRORS.any? { |klass| e.is_a?(klass) }
        str = Utils.exception_to_message(e)
        notice str unless str =~ /!DOCTYPE/
      end

      @server.log.error e.inspect
      e.backtrace.each do |l|
        @server.log.error "\t#{l}"
      end
    end

    DEFAULT_INTERVAL = 60

    def async(options = {})
      count = options[:count] || -1
      interval = options[:interval] || DEFAULT_INTERVAL
      initial_interval = interval
      max_interval = initial_interval * 15
      broken = false

      # 初回は即時実行させるために nil を指定する
      timer = EventMachine.add_periodic_timer nil do
        timer.interval = interval + rand(5) # 適当にバラす
        timer.cancel if count == 0
        count -= 1 if count > 0

        begin
          yield
          interval = initial_interval
          broken = false
        rescue => e
          interval = (interval * 1.5).to_i

          if interval >= max_interval
            interval = max_interval
            unless broken
              notice I18n.t('error.broken')
              broken = true
            end
          end

          send_error_message e
        end
      end

      return timer
    end

    def duplications
      Duplication.objects(@oid)
    end

    def check_duplication(id)
      Duplication.transaction do
        duplications.where(:obj_id => id).first_or_create do |dup|
          yield
        end
      end
    end

    def check_feed
      feed.reverse.each do |item|
        send_message item
      end
    end

    def send_message(item, options = {})
      check_duplication item.id do
        unless @session.user_filter.check_app( :id => item.from.id, :app_id => item.app_id )
          tid = @session.typablemap.push(item)
          # TODO: auto-liker
          #@client.status(item.id).likes(:create) if @opts.autoliker == true
          method = (item.from.id == @session.me['id']) ? :notice : :privmsg
          send method, item.to_s(:tid => tid, :color => @session.options.color), :from => item.from.nick
        else
          @server.log.debug 'app filter:' + item.to_s
        end
      end

      item.comments.each do |comment|
        check_duplication comment.id do
          unless @session.user_filter.get_invisible( :type => :comment , :id => comment.parent.from.id )
            ctid = @session.typablemap.push(comment)
            method = (comment.from.id == @session.me['id']) ? :notice : :privmsg
            send method, comment.to_s(:tid => ctid, :color => @session.options.color), :from => comment.from.nick
          else
            @server.log.debug 'comment filter:' + comment.to_s
          end
        end
      end

      item.likes.each do |like|
        lid = "#{item.id}_like_#{like.from.id}"
        check_duplication lid do
          unless @session.user_filter.get_invisible( :type => :like , :id => like.parent.from.id )
            notice like.to_s(:color => @session.options.color), :from => like.from.nick
          else
            @server.log.debug 'like filter:' + like.to_s
          end
        end
      end if item.from.id == @session.me['id']
    end

    def process_command(message)
      command, args = message.split(/\s+/)
      return false if not OBJECTS.include?(command)

      @server.log.debug "command: #{[command, args].to_s}"

      items = @session.api.me.send(command)['data'].reverse
      @server.log.debug "items: #{items.to_s}"

      if items.empty?
        notice 'no match found'
      else
        if args.nil?
          # list show
          items.each_with_index do |item, index|
            notice "#{index + 1}: #{object_name item}"
          end
        else
          # set object
          item = items[args.to_i - 1]
          if item
            start item['id']
            save
          else
            notice 'invalid argument'
          end
        end
      end

      return true
    end

    def error_messages(e)
      @server.error_messages e
    end
  end

  class NewsFeedChannel < Channel
    def save
      # 保存しない
    end

    def destroy
    end

    def feed
      Feed.new(@object.home, @session.user_filter)
    end
  end

end

