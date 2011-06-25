class CreateChannels < ActiveRecord::Migration
  def self.up
    create_table :channels do |t|
      t.string :uid, :null => false, :primary => true
      t.string :name, :null => false
      t.string :mode
      t.string :oid
      t.timestamps
    end

    change_table :channels do |t|
      t.index [:uid, :name]
    end
  end

  def self.down
    drop_table :channels
  end
end
