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

ActiveRecord::Schema[8.0].define(version: 2026_11_08_100006) do
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

  create_table "audit_events", force: :cascade do |t|
    t.datetime "occurred_at", null: false
    t.string "actor", null: false
    t.string "action", null: false
    t.string "target_type"
    t.string "target_id"
    t.jsonb "details", default: {}, null: false
    t.string "prev_hash", limit: 64, null: false
    t.string "event_hash", limit: 64, null: false
    t.index ["actor", "occurred_at"], name: "index_audit_events_on_actor_and_occurred_at"
    t.index ["event_hash"], name: "index_audit_events_on_event_hash", unique: true
    t.index ["target_type", "target_id"], name: "index_audit_events_on_target_type_and_target_id"
  end

  create_table "deduction_lines", force: :cascade do |t|
    t.bigint "salary_record_id", null: false
    t.string "label", null: false
    t.decimal "amount", precision: 18, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["salary_record_id"], name: "index_deduction_lines_on_salary_record_id"
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

  create_table "exchange_rates", force: :cascade do |t|
    t.string "currency", limit: 3, null: false
    t.integer "year", null: false
    t.decimal "rate_to_usd", precision: 18, scale: 8, null: false
    t.integer "version", null: false
    t.string "reason", null: false
    t.string "set_by", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["currency", "year", "version"], name: "index_exchange_rates_on_currency_and_year_and_version", unique: true
  end

  create_table "import_batches", force: :cascade do |t|
    t.string "filename", null: false
    t.string "file_sha256", limit: 64, null: false
    t.string "uploaded_by", null: false
    t.string "status", default: "staged", null: false
    t.integer "total_rows", default: 0, null: false
    t.integer "accepted_rows", default: 0, null: false
    t.integer "rejected_rows", default: 0, null: false
    t.string "committed_by"
    t.datetime "committed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["file_sha256"], name: "index_import_batches_on_file_sha256", unique: true
  end

  create_table "import_rows", force: :cascade do |t|
    t.bigint "import_batch_id", null: false
    t.integer "row_number", null: false
    t.string "status", null: false
    t.jsonb "raw", default: {}, null: false
    t.jsonb "data"
    t.string "reasons", default: [], null: false, array: true
    t.index ["import_batch_id", "row_number"], name: "index_import_rows_on_import_batch_id_and_row_number", unique: true
    t.index ["import_batch_id"], name: "index_import_rows_on_import_batch_id"
  end

  create_table "role_snapshots", force: :cascade do |t|
    t.string "email", null: false
    t.string "roles", default: [], null: false, array: true
    t.datetime "seen_at", null: false
    t.index ["email", "seen_at"], name: "index_role_snapshots_on_email_and_seen_at"
  end

  create_table "salary_records", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.string "currency", limit: 3, null: false
    t.string "country", limit: 2, null: false
    t.decimal "base_pay", precision: 18, scale: 2, null: false
    t.decimal "gross", precision: 18, scale: 2, null: false
    t.decimal "net", precision: 18, scale: 2, null: false
    t.date "effective_from", null: false
    t.integer "version", default: 1, null: false
    t.string "created_by", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "import_batch_id"
    t.index ["employee_id", "effective_from", "version"], name: "idx_on_employee_id_effective_from_version_9bb800c71b", unique: true
    t.index ["employee_id"], name: "index_salary_records_on_employee_id"
    t.index ["import_batch_id"], name: "index_salary_records_on_import_batch_id"
  end

  add_foreign_key "assignments", "employees"
  add_foreign_key "deduction_lines", "salary_records"
  add_foreign_key "import_rows", "import_batches"
  add_foreign_key "salary_records", "employees"
  add_foreign_key "salary_records", "import_batches"
end
