# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_11_08_100001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "assignments", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.string "department", null: false
    t.string "job_title", null: false
    t.date "effective_from", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "effective_from"], name: "index_assignments_on_employee_id_and_effective_from", unique: true
    t.index ["employee_id"], name: "index_assignments_on_employee_id"
  end

  create_table "employees", force: :cascade do |t|
    t.string "employee_number", null: false
    t.string "name", null: false
    t.string "country", limit: 2, null: false
    t.date "hire_date", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_number"], name: "index_employees_on_employee_number", unique: true
  end

  add_foreign_key "assignments", "employees"
end
