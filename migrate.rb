require 'rubygems'
require 'active_record'

ActiveRecord::Base.establish_connection(
  :adapter  => $opts[:db][:adapter],
  :database => $opts[:db][:database]
)

class InitialSchema < ActiveRecord::Migration
  def self.up
    create_table :settings do |t|
      t.column :real_name, :string, :null => false
      t.column :nick_name, :string, :null => false
      t.column :app_id, :string, :null => false
      t.column :app_secret, :string, :null => false
      t.column :app_code, :string, :null => false
      t.timestamps
    end

    create_table :duplications do |t|
      t.column :parent_id, :string, :null => false, :primary => true
      t.column :object_id, :string, :null => false
      t.timestamps
    end
    change_table :duplications do |t|
      t.index [:parent_id, :object_id]
    end
  end
  
  def self.down
    drop_table :settings
    drop_table :duplications
  end
end

InitialSchema.migrate(:up) unless File.exists? $opts[:db][:database]

