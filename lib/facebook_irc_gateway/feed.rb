# coding: utf-8
module FacebookIrcGateway
  class User
    attr_accessor :id, :name, :nick

    def initialize(id, name, filter)
      @id = id
      @name = name
      @nick = filter.get_name :id => id, :name => name
    end
  end

  class Entry
    attr_accessor :type, :id, :message
    attr_accessor :from, :to
    attr_accessor :comments, :likes
    
    def initialize(data, filter)
      @filter = filter
      parse data
    end

    def app_name
      @application['name'] rescue 'web'
    end

    def app_id
      @application['id'] rescue nil
    end

    def to_s(options = {})
      @color = options[:color] || {}

      terms = []
      terms << @message
      terms << @story
      terms << @name
      terms << @caption
      terms << @description
      terms << @link

      terms.select! { |t| t.is_a?(String) && !t.empty? }
      terms.map! { |t| apply_filter t }

      tokens = []
      tokens << terms.join(' / ')
      tokens << ">> #{@to.map(&:name).uniq.join(', ')}".irc_colorize(:color => @color[:parent_message]) if @to && !@to.empty?
      tokens << "(#{options[:tid]})".irc_colorize(:color => @color[:tid]) if options[:tid]
      tokens << "(via #{app_name})".irc_colorize(:color => @color[:app_name])
      tokens.join(' ')
    end

    protected

    def parse(data)
      data.each { |k, v| instance_variable_set "@#{k}", v }

      @from = User.new(@from['id'], @from['name'], @filter) if @from
      @to = @to['data'].compact.map { |h| User.new(h['id'], h['name'], @filter) } rescue [] if @to
      @type = @type.to_sym if @type
      @comments = @comments['data'].map { |data| Comment.new(self, data, @filter) } rescue []
      @likes = @likes['data'].map { |data| Like.new(self, data, @filter) } rescue []
    end

    def apply_filter(str, options = {})
      length = options[:length] || 100
      str = str.to_s
      str = Utils.url_filter(str)
      str = str.truncate(length)
      str
    end
  end

  class Like < Entry
    attr_accessor :parent

    def initialize(parent, data, filter)
      super data, filter
      @parent = parent
    end

    def to_s(options = {})
      color = options[:color] || {}

      tokens = []
      tokens << '(like)'.irc_colorize(:color => color[:like])
      tokens << @parent.to_s
      tokens.join(' ')
    end

    private

    def parse(data)
      super
      @from = User.new(@id, @name, @filter)
    end
  end

  class Comment < Entry
    attr_accessor :parent

    def initialize(parent, data, filter)
      super data, filter
      @parent = parent
    end

    def to_s(options = {})
      color = options[:color] || {}

      tokens = []
      tokens << apply_filter(@message)
      tokens << "(#{options[:tid]})".irc_colorize(:color => color[:tid]) if color[:tid]
      tokens << ">> #{@parent.from.nick}: #{@parent.to_s}".irc_colorize(:color => color[:parent_message]) if color[:tid]
      tokens.join(' ')
    end
  end

  class Feed < Array
    def initialize(data, filter)
      items = data['data'] || []
      concat items.map { |item| Entry.new(item, filter) }
    end
  end

  # TODO: このファイルにあるのはおかしいので後で移動する
  class Friends < Array
    def initialize(data, filter)
      items = data['data'] || []
      concat items.map { |item| User.new(item['id'], item['name'], filter) }
    end
  end
end

