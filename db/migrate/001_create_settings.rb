class CreateSettings < ActiveRecord::Migration
  def self.up
    create_table :settings do |t|
      t.column :real_name, :string, :null => false
      t.column :nick_name, :string, :null => false
      t.column :app_id, :string, :null => false
      t.column :app_secret, :string, :null => false
      t.column :app_code, :string, :null => false
      t.timestamps
    end
  end

  def self.down
    drop_table :settings
  end
end
