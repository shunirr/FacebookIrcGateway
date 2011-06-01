class CreateUserFilters < ActiveRecord::Migration
  def self.up
    create_table :user_filters do |t|
      t.column :user_id, :string, :null => false, :primary => true
      t.column :object_id, :string, :null => false
      t.column :alias, :string
      t.column :filter_app, :string, :null => false, :default => ''
      t.column :invisible_comment, :boolean, :null => false , :default => false
      t.column :invisible_like, :boolean, :null => false , :default => false
      t.timestamps
    end
  end

  def self.down
    drop_table :user_filters
  end
end
