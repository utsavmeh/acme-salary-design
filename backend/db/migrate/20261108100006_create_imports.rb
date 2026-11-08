class CreateImports < ActiveRecord::Migration[8.0]
  def change
    create_table :import_batches do |t|
      t.string :filename, null: false
      t.string :file_sha256, null: false, limit: 64
      t.string :uploaded_by, null: false
      t.string :status, null: false, default: "staged"
      t.integer :total_rows, null: false, default: 0
      t.integer :accepted_rows, null: false, default: 0
      t.integer :rejected_rows, null: false, default: 0
      t.string :committed_by
      t.datetime :committed_at
      t.timestamps
    end
    # The same file cannot be staged twice, so a double upload cannot double-load the data.
    add_index :import_batches, :file_sha256, unique: true

    create_table :import_rows do |t|
      t.references :import_batch, null: false, foreign_key: true
      t.integer :row_number, null: false
      t.string :status, null: false
      t.jsonb :raw, null: false, default: {}
      t.jsonb :data
      t.string :reasons, array: true, null: false, default: []
    end
    add_index :import_rows, %i[import_batch_id row_number], unique: true

    add_reference :salary_records, :import_batch, foreign_key: true
  end
end
