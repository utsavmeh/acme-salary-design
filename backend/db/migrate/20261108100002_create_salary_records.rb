class CreateSalaryRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :salary_records do |t|
      t.references :employee, null: false, foreign_key: true
      t.string :currency, null: false, limit: 3
      t.string :country, null: false, limit: 2
      t.decimal :base_pay, null: false, precision: 18, scale: 2
      t.decimal :gross, null: false, precision: 18, scale: 2
      t.decimal :net, null: false, precision: 18, scale: 2
      t.date :effective_from, null: false
      t.integer :version, null: false, default: 1
      t.string :created_by, null: false
      t.timestamps
    end
    # A correction is a new row with the same date and a higher version.
    add_index :salary_records, %i[employee_id effective_from version], unique: true

    create_table :deduction_lines do |t|
      t.references :salary_record, null: false, foreign_key: true
      t.string :label, null: false
      t.decimal :amount, null: false, precision: 18, scale: 2
      t.timestamps
    end
  end
end
