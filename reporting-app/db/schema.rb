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

ActiveRecord::Schema[7.2].define(version: 2025_10_14_151917) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.uuid "record_id", null: false
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "activities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "activity_report_application_form_id", null: false
    t.date "month"
    t.decimal "hours"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["activity_report_application_form_id"], name: "index_activities_on_activity_report_application_form_id"
  end

  create_table "activity_report_application_forms", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id"
    t.integer "status"
    t.datetime "submitted_at"
    t.uuid "certification_id"
    t.uuid "certification_case_id"
    t.jsonb "reporting_periods"
    t.index ["certification_case_id"], name: "idx_on_certification_case_id_df9964575c"
    t.index ["certification_id"], name: "index_activity_report_application_forms_on_certification_id"
  end

  create_table "certification_cases", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "certification_id", null: false
    t.integer "status"
    t.string "business_process_current_step"
    t.jsonb "facts"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["certification_id"], name: "index_certification_cases_on_certification_id"
  end

  create_table "certifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "member_id"
    t.text "case_number"
    t.jsonb "certification_requirements"
    t.jsonb "member_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["case_number"], name: "index_certifications_on_case_number"
    t.index ["member_id"], name: "index_certifications_on_member_id"
  end

  create_table "exemption_application_forms", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.integer "status"
    t.datetime "submitted_at"
    t.string "exemption_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "certification_id"
    t.uuid "certification_case_id"
    t.index ["certification_case_id"], name: "index_exemption_application_forms_on_certification_case_id"
    t.index ["certification_id"], name: "index_exemption_application_forms_on_certification_id"
  end

  create_table "information_requests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "type", null: false
    t.uuid "application_form_id", null: false
    t.string "application_form_type", null: false
    t.text "staff_comment", null: false
    t.text "member_comment"
    t.date "due_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "strata_tasks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "type"
    t.text "description"
    t.integer "status", default: 0
    t.uuid "assignee_id"
    t.uuid "case_id"
    t.date "due_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "case_type"
    t.index ["assignee_id"], name: "index_strata_tasks_on_assignee_id"
    t.index ["case_id", "case_type"], name: "index_strata_tasks_on_case_id_and_case_type"
    t.index ["status"], name: "index_strata_tasks_on_status"
    t.index ["type"], name: "index_strata_tasks_on_type"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "uid", null: false
    t.string "provider", null: false
    t.string "email", default: "", null: false
    t.integer "mfa_preference"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["uid"], name: "index_users_on_uid", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activities", "activity_report_application_forms"
  add_foreign_key "activity_report_application_forms", "certification_cases"
  add_foreign_key "activity_report_application_forms", "certifications"
  add_foreign_key "certification_cases", "certifications"
  add_foreign_key "exemption_application_forms", "certification_cases"
  add_foreign_key "exemption_application_forms", "certifications"
end
