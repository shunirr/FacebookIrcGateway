require 'facebook_irc_gateway/utils'

module FacebookIrcGateway
  class User
    attr :id
    attr :name
    def initialize(id, name)
      @id   = id
      @name = name.gsub(/\s+/, '')
    end
  end

  class Feed
    attr :type
    attr :id
    attr :comments
    attr :likes
    attr :from

    def initialize(data)
      parse data
    end

    def to_s(options = {})
      @color = options[:color] || {}

      tokens = message_build

      tokens << "(#{options[:tid]})".irc_colorize(:color => @color[:tid]) if options[:tid]
      tokens << "(via #{app_name})".irc_colorize(:color => @color[:app_name])

      tokens.join(' ')
    end
    
    private
    def app_name
      if @application
        return @application['name']
      else
        return 'web'
      end
    end

    def parse(data)
      data.each do |k,v|
        eval("@#{k}=v")
      end
      @from = User.new(@from['id'], @from['name']) if @from
      @type = @type.to_sym if @type
 
      if @comments
        comments = []
        @comments['data'].each do |comment|
          comments << Comment.new(self, comment)
        end
        @comments = comments
      end

      if @likes
        likes = []
        @likes['data'].each do |like|
          likes << Like.new(self, like)
        end
        @likes = likes
      end
    end

    def attach_message(str, tokens)
      if str != nil && str != ''
        tokens << '/' if not tokens.empty?
        tokens << Utils.url_filter(str).truncate(100)
      end

      tokens
    end

    def message_build(tokens = [])
      # TODO: dasai
      tokens = attach_message @message, tokens
      tokens = attach_message @name, tokens
      tokens = attach_message @caption, tokens
      tokens = attach_message @description, tokens
  
      if @link != nil && @link != ''
        tokens << '/' if not tokens.empty?
        tokens << "#{Utils.shorten_url(@link)}"
      end

      tokens
    end
  end

  class Like < Feed
    def initialize(parent, data)
      super data
      @parent = parent
    end

    def to_s(options = {})
      tokens = []

      color = options[:color] || {}
      tokens << '(like)'.irc_colorize(:color => color[:like])

      tokens << @parent.to_s
      tokens.join(' ')
    end

    private
    def parse(data)
      super
      @from = User.new(@id, @name)
    end
  end

  class Comment < Feed
    def initialize(parent, data)
      super data
      @parent = parent
    end

    def to_s(options = {})
      tokens = message_build

      color = options[:color] || {}
      tokens << "(#{options[:tid]})".irc_colorize(:color => color[:tid]) if color[:tid]
      tokens << '>>'.to_s.irc_colorize(:color => color[:parent_message])
      tokens << @parent.to_s.irc_colorize(:color => color[:parent_message])

      tokens.join(' ')
    end

    private
    def message_build(tokens = [])
      tokens = attach_message @message, tokens
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

  # TODO: このファイルにあるのはおかしいので後で移動する
  class Friends < Array
    def initialize(data)
      data['data'].each do |i|
        self << User.new(i['id'], i['name'])
      end
    end
  end
end

