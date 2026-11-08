class CreateEmployees < ActiveRecord::Migration[8.0]
  def change
    create_table :employees do |t|
      t.string :employee_number, null: false
      t.string :name, null: false
      t.string :country, null: false, limit: 2
      t.date :hire_date, null: false
      t.string :status, null: false, default: "active"
      t.timestamps
    end
    add_index :employees, :employee_number, unique: true

    create_table :assignments do |t|
      t.references :employee, null: false, foreign_key: true
      t.string :department, null: false
      t.string :job_title, null: false
      t.date :effective_from, null: false
      t.timestamps
    end
    add_index :assignments, %i[employee_id effective_from], unique: true
  end
end
