class CreateAuditEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_events do |t|
      t.datetime :occurred_at, null: false, precision: 6
      t.string :actor, null: false
      t.string :action, null: false
      t.string :target_type
      t.string :target_id
      t.jsonb :details, null: false, default: {}
      t.string :prev_hash, null: false, limit: 64
      t.string :event_hash, null: false, limit: 64
    end
    add_index :audit_events, :event_hash, unique: true
    add_index :audit_events, %i[actor occurred_at]
    add_index :audit_events, %i[target_type target_id]
  end
end
