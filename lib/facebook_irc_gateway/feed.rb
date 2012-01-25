# coding: utf-8
module FacebookIrcGateway
  class User
    attr :id
    attr :name
    attr :nick

    def initialize(id, name, filter)
      @id   = id
      @name = name
      @nick = filter.get_name :id => id, :name => name
    end
  end

  class Entry
    attr :type
    attr :id
    attr :comments
    attr :likes
    attr :from
    attr :message
    attr :to
    
    def initialize(data,filter)
      @filter = filter
      parse data
    end

    def to_s(options = {})
      @color = options[:color] || {}

      tokens = message_build
      tokens << " >> #{@to.map(&:name).uniq.join(' ')}".irc_colorize(:color => @color[:parent_message]) if @to
      tokens << "(#{options[:tid]})".irc_colorize(:color => @color[:tid]) if options[:tid]
      tokens << "(via #{app_name})".irc_colorize(:color => @color[:app_name])

      tokens.join(' ')
    end
    
    def app_name
      if @application
        return @application['name']
      else
        return 'web'
      end
    end

    def app_id
      if @application
        return @application['id']
      else
        return nil
      end
    end

    private
    def parse(data)
      data.each do |k,v|
        eval("@#{k}=v")
      end
      @from = User.new(@from['id'], @from['name'],@filter) if @from
      @to = @to['data'].map{|m| User.new(m['id'], m['name'],@filter)}if @to && @to['data']
      @type = @type.to_sym if @type

      comments = []
      if @comments and @comments.class == Hash
        if @comments['data'] and @comments['data'].class == Array
          @comments['data'].each do |comment|
            comments << Comment.new(self, comment, @filter)
          end
        end
      end
      @comments = comments

      likes = []
      if @likes and @likes.class == Hash
        if @likes['data'] and @likes['data'].class == Array
          @likes['data'].each do |like|
            likes << Like.new(self, like,@filter)
          end
        end
      end
      @likes = likes

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

  class Like < Entry
    attr :parent
    def initialize(parent, data, filter)
      super data,filter
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
      @from = User.new(@id, @name,@filter)
    end
  end

  class Comment < Entry
    attr :parent
    def initialize(parent, data, filter)
      super data,filter
      @parent = parent
    end

    def to_s(options = {})
      tokens = message_build

      color = options[:color] || {}
      tokens << "(#{options[:tid]})".irc_colorize(:color => color[:tid]) if color[:tid]
      mes = ">> #{@parent.from.nick}: #{@parent.to_s}"
      tokens << mes.irc_colorize(:color => color[:parent_message])
      tokens.join(' ')
    end

    private
    def message_build(tokens = [])
      tokens = attach_message @message, tokens
      tokens
    end
  end

  class Feed < Array
    def initialize(data,filter)
      items = data['data']
      unless items.nil?
        items.each do |d|
          self << Entry.new(d,filter)
        end
      end
    end
  end

  # TODO: このファイルにあるのはおかしいので後で移動する
  class Friends < Array
    def initialize(data,filter)
      data['data'].each do |i|
        self << User.new(i['id'], i['name'],filter)
      end
    end
  end
end

