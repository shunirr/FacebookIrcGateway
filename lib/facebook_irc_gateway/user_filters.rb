module FacebookIrcGateway
  class UserFilters

    def initialize( uid )
      @user_id = uid
      @filter = UserFilter.where( :user_id => @user_id )
    end

    def get_name(options={})
      if options[:data]
        id   = options[:data]['id']
        name = options[:data]['name'].gsub(/\s+/, '')
      else
        id   = options[:id]
        name = options[:name].gsub(/\s+/, '')
      end

      if record = @filter.find_by_object_id( id ) and record.alias != nil
        name = record.alias
      end
      name
    end

    def set_name(options={})
      id   = options[:id]
      name = options[:name].gsub(/\s+/, '')

      record = @filter.find_or_initialize_by_object_id( id )
      record.alias = name

      record.save
    end

    @@invisible_types = { 'comment' => true ,'like' => true }
    def get_invisible(options={})
      id   = options[:id]
      type = options[:type]
      if @@invisible_types[ type ] and record = @filter.find_by_object_id( id )
        return record.instance_variable_get("@invisible_#{type}")
      end
      return false
    end

    def set_invisible(options={})
      id   = options[:id]
      type = options[:type]
      val  = options[:val] 

      if @@invisible_types[ type ]
        record = @filter.find_or_initialize_by_object_id( id )
        record.instance_variable_set("@invisible_#{type}",val)
      end
    end
  end
end
