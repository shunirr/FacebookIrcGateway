require 'active_record'

module FacebookIrcGateway
  class Duplication < ActiveRecord::Base

    scope :objects, lambda { |id| where(:parent_id => id) }

  end
end

