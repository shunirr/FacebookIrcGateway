
# timeline_data = @timeline.me.home
# feeds = Feeds.new(timeline_data)
# 
# feeds.each do |feed|
#   next if feed.type != :status
#   tid = @typablemap(feed.id)
#   post feed.from.name, PRIVMSG, feed.to_s_with_tid(tid)
# end

module FacebookIrcGateway
  class Feed
    attr :type
    attr :id

    def initialize(data)
      parse data
    end

    def to_s_with_tid(tid)
      tokens = message_build
      tokens << "(#{tid})"

      tokens.join(' ')
    end

    def to_s
      tokens = message_build
      tokens.join(' ')
    end
    
    private
    def parse(data)
      data.each do |k,v|
        eval("@#{k}=v")
      end
      @from = User.new(data['from']['id'], data['from']['name'])
      @type = data['type'].to_sym
    end

    def message_build(tokens)
      tokens = [] if tokens.nil?

      # TODO
      if @message != nil && @message != ''
        tokens << Utils.url_filter(@message)
      end

      tokens
    end
  end

  class Feeds < Array
    def initialize(data)
      data['data'].each do |d|
        self << Feed.new(d)
      end
    end
  end

  class User
    attr :id
    attr :name
    def initialize(id, name)
      @id   = id
      @name = name
    end
  end

  # TODO: このファイルにあるのはおかしいので後で移動する
  class Friends < Array
    def initialize(data)
      data['data'].each do |i|
        self << User.new(i['id'], i['name'])
      end
    end
  end
end

