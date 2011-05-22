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
    def send_irc_command(command, options = {})
      from = (options[:from] || @server.server_name).gsub(/\s+/, '')
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
      return if process_command(message)

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
      start topic
    end
    # }}}

    def has_object?
      not @object.nil?
    end

    def object_name(item)
      item.inject([]) do |result, (key, value)|
        result << value if ['name', 'category'].include? key; result
      end.join(' / ')
    end
    # }}}

    private

    def start(id)
      @object = FacebookOAuth::FacebookObject.new(id, @session.api)
      @duplications = Duplication.objects(id)

      notice "start: #{object_name @object.info}"

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

    def update(message)
      @object.feed(:create, :message => message)
    end

    def check_duplication(id)
      dup = @duplications.find_or_initialize_by_object_id(id)
      new = dup.new_record?
      dup.save
      yield if new
    end

    def check_feed
      #@server.log.debug 'begin: check_feed'
      feed.reverse.each do |item|
        send_message item
      end
      #@server.log.debug 'end: check_feed'
    end

    def send_message(item, options = {})
      id          = item['id']
      from_id     = item['from']['id']
      from_name   = item['from']['name'] || server_name
      tos         = item['to']['data'] if item['to']
      picture     = item['picture']
      link        = item['link']
      name        = item['name']
      if item['properties']
        properties = item['properties'].map {|p| p['text'] }
      end
      icon        = item['icon']
      type        = item['type']
      object_id   = item['object_id']
      if item['application']
        app_id    = item['application']['id']
        app_name  = item['application']['name'] || 'web'
      end
      message     = item['message'].to_s
      caption     = item['caption']
      description = item['description'].to_s.truncate(100)
      comments    = item['comments'] && item['comments']['data'] || []
      likes       = item['likes'] && item['likes']['data'] || []

      check_duplication id do
        tid = @session.typablemap.push([id, item])

        msgs = []
        msgs << message
        msgs << name
        msgs << caption
        msgs << description

        tokens = []
        tokens << msgs.select { |s| !(s.nil? or s.empty?) }.join(' / ')
        tokens << "#{Utils.shorten_url(link)}" if link
        tokens << "(#{tid})".irc_colorize(:color => @server.opts.color[:tid]) if tid
        tokens << "(via #{app_name})".irc_colorize(:color => @server.opts.color[:app_name])

        @session.api.status(id).likes(:create) if @server.opts.autoliker == true
        method = (from_id == @session.me_info['id']) ? :notice : :privmsg
        send method, tokens.join(' '), :from => from_name
      end

      comments.each do |comment|
        cid   = comment['id']
        cname = comment['from']['name']
        cmes  = Utils.url_filter(comment['message'])

        check_duplication cid do
          ctid = @session.typablemap.push([cid, item])
          tokens = [
            cmes,
            "(#{ctid})".irc_colorize(:color => @server.opts.color[:tid]),
            ">> #{from_name}: #{message}".irc_colorize(:color => @server.opts.color[:parent_message])
          ]
          method = (comment['from']['id'] == @session.me_info['id']) ? :notice : :privmsg
          send method, tokens.join(' '), :from => cname
        end
      end

      likes.each do |like|
        lid   = "#{id}_like_#{like['id']}"
        lname = like['name']
        check_duplication lid do
          tokens = [I18n.t('server.like_mark').irc_colorize(:color => @server.opts.color[:like]), "#{from_name}: ", message]
          notice tokens.join(' '), :from => lname
        end
      end
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
      # News feed を購読開始
      start @session.me_info['id']
    end

    def feed
      @object.home['data']
    end
  end

end

