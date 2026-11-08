# Roles used to come from sign-in groups and were tracked here. They now live on the user.
class DropRoleSnapshots < ActiveRecord::Migration[8.0]
  def change
    drop_table :role_snapshots do |t|
      t.string :email, null: false
      t.string :roles, array: true, null: false, default: []
      t.datetime :seen_at, null: false
    end
  end
end
