class CreateApnDevices < ActiveRecord::Migration # :nodoc:
  def self.up
    create_table :apn_devices do |t|
      t.text :token, :size => 71, :null => false
      t.integer :user_id
      t.timestamps
    end
  end

  def self.down
    drop_table :apn_devices
  end
end
