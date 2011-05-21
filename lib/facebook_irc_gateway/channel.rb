require 'facebook_oauth'
require 'facebook_irc_gateway/models/duplication'

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

    def initialize(server, session, name)
      @server = server
      @session = session
      @name = name
      @topic = nil
      @object = nil
    end

    # IRC methods {{{1
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
    #}}}

    # Events {{{1
    def on_privmsg(message)
      # check command
      return if process_command(message)

      if has_object?
        update message
        @server.log.debug item.to_s
      else
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

    def has_object?
      @object.nil?
    end

    def object_name(item)
      tokens = item.inject([]) do |result, (key, value)|
        result << value if ['name', 'category'].include? key
        result
      end
      tokens.join(' / ')
    end
    # }}}

    private

    def start(id)
      @object = FacebookOAuth::FacebookObject.new(id, @server.client)
      @duplications = Duplication.objects(id)

      notice "set: #{object_name @object.info}"

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

    def feed
      @object.feed['data']
    end

    def update
      @object.feed(:create, :message => message)
    end

    def check_duplication(id)
      dup = @duplications.find_or_initialize_by_object_id(id)
      new = dup.new_record?
      dup.save
      yield if new
    end

    def check_feed
      @server.log.debug 'begin: check_feed'
      feed.reverse.each do |item|
        check_duplication item['id'] do
          #TODO: いい感じに出力する
          name = item['from']['name'].gsub(/\s+/, '') || ''
          message = item['message'] || ''
          privmsg message, :from => name
        end
      end
      @server.log.debug 'end: check_feed'
    end

    def process_command(message)
      command, args = message.split(/\s+/)
      return false if not OBJECTS.include?(command)

      @server.log.debug "command: #{[command, args].to_s}"

      items = @server.client.me.send(command)['data'].reverse
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
          else
            notice 'invalid argument'
          end
        end
      end

      return true
    end

  end

  class MainChannel < Channel
    def initialize(server, session, name)
      super
      start session.me['id']
    end

    def feed
      @object.home['data']
    end
  end

end

