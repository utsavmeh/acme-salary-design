class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :username, null: false
      t.string :password_digest, null: false
      t.string :roles, array: true, null: false, default: []
      t.string :status, null: false, default: "active"
      t.boolean :must_change_password, null: false, default: true
      t.integer :failed_attempts, null: false, default: 0
      t.datetime :locked_until
      t.datetime :last_login_at
      t.timestamps
    end
    add_index :users, :username, unique: true
  end
end
