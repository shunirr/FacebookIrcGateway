module FacebookIrcGateway
  class UserFilters
    INVISIBLE_TYPES = { :comment => 'comment' , :like => 'like' }

    def initialize( uid )
      @user_id = uid
      @filter = UserFilter.where( :user_id => @user_id )
    end

    def get_name(options={})
      if options[:data]
        id   = options[:data]['id']
        name = Utils.sanitize_name(options[:data]['name'])
      else
        id   = options[:id]
        name = Utils.sanitize_name(options[:name])
      end

      if record = @filter.find_by_object_id( id ) and record.alias != nil
        name = record.alias
      end
      name
    end

    def set_name(options={})
      id   = options[:id]
      name = Utils.sanitize_name(options[:name])

      record = @filter.find_or_initialize_by_object_id( id )
      record.alias = name

      record.save
    end

    def get_invisible(options={})
      id   = options[:id]
      type = options[:type]
      result = false
      
      record = @filter.find_by_object_id( id )
      if INVISIBLE_TYPES[ type ] and record
        result = record.send("invisible_#{INVISIBLE_TYPES[type]}")
      end
      result
    end

    def set_invisible(options={})
      id   = options[:id]
      type = options[:type]
      if options[:val].nil? 
        val = true
      else
        val = options[:val]
      end

      if INVISIBLE_TYPES[ type ]
        record = @filter.find_or_initialize_by_object_id( id )
        record.send("invisible_#{INVISIBLE_TYPES[type]}=",val)
        record.save
      end
    end
  end
end
