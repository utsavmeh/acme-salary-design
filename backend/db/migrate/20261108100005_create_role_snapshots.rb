class CreateRoleSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :role_snapshots do |t|
      t.string :email, null: false
      t.string :roles, array: true, null: false, default: []
      t.datetime :seen_at, null: false
    end
    add_index :role_snapshots, %i[email seen_at]
  end
end
