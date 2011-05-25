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
      'checkins']

    def initialize(server, name)
      @server = server
      @name = name
      @topic = nil
      @object = nil
    end

    # Helpers {{{1
    def post(command, options = {})
      from = options[:from] || @server.server_name
      channel = options[:channel] || @name
      params = options[:params] || []
      @server.post from, command, channel, *params
    end

    def privmsg(message, options = {})
      post 'PRIVMSG', options.merge(:params => [message])
    end

    def notice(message, options = {})
      post 'NOTICE', options.merge(:params => [message])
    end

    def object_name(item)
      tokens = item.inject([]) do |result, (key, value)|
        result << value if ['name', 'category'].include? key
        result
      end
      tokens.join(' / ')
    end
    # }}}

    # Events {{{1
    def on_privmsg(message)
      # check object command
      command, args = message.split(/\s+/)
      @server.log.debug "command: #{[command, args].to_s}"

      if OBJECTS.include?(command)
        items = @server.client.me.send(command)['data'].reverse
        @server.log.debug "items: #{items.to_s}"

        if items.empty?
          notice 'no match found'
          return
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
            else
              notice 'invalid argument'
            end
          end
        end

        return
      end

      if @object
        feed_post message
        @server.log.debug item.to_s
      end
    end

    def on_join
    end

    def on_part
      stop
    end

    def on_topic(topic)
      start topic
    end
    # }}}

    private

    def start(id)
      @object = FacebookOAuth::FacebookObject.new(id, @server.client)
      @dupulications = Duplication.objects id

      notice "bind: #{object_name @object.info}"

      stop
      @check_feed_thread = async do
        check_feed
      end
    end

    def stop
      if @check_feed_thread
        @check_feed_thread.exit
        @check_feed_thread.join
        @check_feed_thread = nil
      end
    end

    def async(options = {})
      @server.log.debug 'begin: async'
      count = options[:count] || 0
      interval = options[:interval] || 30

      return Thread.start do
        loop do
          if count > 0
            count -= 1
            break if count == 0
          end

          begin
            yield
          rescue Exception => e
            @server.log.error "#{__FILE__}: #{__LINE__}L"
            @server.log.error e.inspect
            e.backtrace.each do |l|
              @server.log.error "\t#{l}"
            end
          end

          sleep interval
        end
        @server.log.debug 'end: async'
      end
    end

    def feed_get
      @object.feed['data']
    end

    def feed_post message
      @object.feed(:create, :message => message)
    end

    def check_feed
      @server.log.debug 'begin: check_feed'
      feed_get.reverse.each do |item|
        @dupulications.find_or_create_by_object_id item['id'] do
          #TODO: いい感じに出力する
          name = item['from']['name'].gsub(/\s+/, '')
          message = item['message']
          privmsg message, :from => name
        end
      end
      @server.log.debug 'end: check_feed'
    end
  end
end

