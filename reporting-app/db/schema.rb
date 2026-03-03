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

ActiveRecord::Schema[7.2].define(version: 2026_02_17_190932) do
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
    t.string "type"
    t.integer "income"
    t.string "category", default: "employment", null: false
    t.index ["activity_report_application_form_id"], name: "index_activities_on_activity_report_application_form_id"
    t.index ["category"], name: "index_activities_on_category"
  end

  create_table "activity_report_application_forms", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id"
    t.integer "status"
    t.datetime "submitted_at"
    t.uuid "certification_case_id"
    t.jsonb "reporting_periods"
    t.index ["certification_case_id"], name: "idx_on_certification_case_id_df9964575c", unique: true
  end

  create_table "certification_batch_upload_audit_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "certification_batch_upload_id", null: false
    t.integer "chunk_number", null: false
    t.string "status", default: "started", null: false
    t.integer "succeeded_count", default: 0
    t.integer "failed_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["certification_batch_upload_id", "chunk_number"], name: "idx_audit_logs_on_upload_chunk"
    t.index ["certification_batch_upload_id"], name: "idx_on_certification_batch_upload_id_eb583b913c"
    t.index ["status"], name: "idx_audit_logs_on_status"
  end

  create_table "certification_batch_upload_errors", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "certification_batch_upload_id", null: false
    t.integer "row_number", null: false
    t.string "error_code", null: false
    t.string "error_message", null: false
    t.jsonb "row_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["certification_batch_upload_id", "error_code"], name: "idx_upload_errors_on_upload_code"
    t.index ["certification_batch_upload_id"], name: "idx_on_certification_batch_upload_id_d6e2f52eea"
  end

  create_table "certification_batch_uploads", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "filename", null: false
    t.string "status", default: "pending", null: false
    t.uuid "uploader_id", null: false
    t.integer "num_rows", default: 0, null: false
    t.integer "num_rows_processed", default: 0, null: false
    t.integer "num_rows_succeeded", default: 0, null: false
    t.integer "num_rows_errored", default: 0, null: false
    t.jsonb "results", default: {}
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source_type", default: "ui"
    t.index ["created_at"], name: "index_certification_batch_uploads_on_created_at"
    t.index ["source_type"], name: "index_certification_batch_uploads_on_source_type"
    t.index ["uploader_id"], name: "index_certification_batch_uploads_on_uploader_id"
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

  create_table "certification_origins", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "certification_id", null: false
    t.string "source_type", null: false
    t.uuid "source_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["certification_id"], name: "index_certification_origins_on_certification_id", unique: true
    t.index ["source_type", "source_id"], name: "index_certification_origins_on_source_type_and_source_id"
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

  create_table "ex_parte_activities", id: :uuid, default: -> { "gen_random_uuid()" }, comment: "Hours data from external sources (API/batch) for compliance calculation", force: :cascade do |t|
    t.string "member_id", null: false, comment: "Member reference - always required"
    t.string "category", null: false, comment: "Activity category: employment, community_service, education"
    t.decimal "hours", precision: 8, scale: 2, null: false, comment: "Hours worked/volunteered (max 8760 = 365 days × 24 hours)"
    t.date "period_start", null: false, comment: "Activity period start date"
    t.date "period_end", null: false, comment: "Activity period end date"
    t.string "source_type", null: false, comment: "Source type: 'api' or 'batch_upload'"
    t.string "source_id", comment: "Source record ID (e.g., batch upload ID)"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["member_id"], name: "index_ex_parte_activities_on_member_id", comment: "Lookup entries by member"
    t.index ["period_start", "period_end"], name: "index_ex_parte_activities_on_period", comment: "Date range queries"
    t.index ["source_type", "source_id"], name: "index_ex_parte_activities_on_source", comment: "Source tracking (batch upload lookups)"
  end

  create_table "exemption_application_forms", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.integer "status"
    t.datetime "submitted_at"
    t.string "exemption_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "certification_case_id"
    t.index ["certification_case_id"], name: "index_exemption_application_forms_on_certification_case_id", unique: true
  end

  create_table "good_job_batches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.jsonb "serialized_properties"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_discard"
    t.text "callback_queue_name"
    t.integer "callback_priority"
    t.datetime "enqueued_at"
    t.datetime "discarded_at"
    t.datetime "finished_at"
    t.datetime "jobs_finished_at"
  end

  create_table "good_job_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id", null: false
    t.text "job_class"
    t.text "queue_name"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.text "error"
    t.integer "error_event", limit: 2
    t.text "error_backtrace", array: true
    t.uuid "process_id"
    t.interval "duration"
    t.index ["active_job_id", "created_at"], name: "index_good_job_executions_on_active_job_id_and_created_at"
    t.index ["process_id", "created_at"], name: "index_good_job_executions_on_process_id_and_created_at"
  end

  create_table "good_job_processes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "state"
    t.integer "lock_type", limit: 2
  end

  create_table "good_job_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "key"
    t.jsonb "value"
    t.index ["key"], name: "index_good_job_settings_on_key", unique: true
  end

  create_table "good_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "queue_name"
    t.integer "priority"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "performed_at"
    t.datetime "finished_at"
    t.text "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id"
    t.text "concurrency_key"
    t.text "cron_key"
    t.uuid "retried_good_job_id"
    t.datetime "cron_at"
    t.uuid "batch_id"
    t.uuid "batch_callback_id"
    t.boolean "is_discrete"
    t.integer "executions_count"
    t.text "job_class"
    t.integer "error_event", limit: 2
    t.text "labels", array: true
    t.uuid "locked_by_id"
    t.datetime "locked_at"
    t.index ["active_job_id", "created_at"], name: "index_good_jobs_on_active_job_id_and_created_at"
    t.index ["batch_callback_id"], name: "index_good_jobs_on_batch_callback_id", where: "(batch_callback_id IS NOT NULL)"
    t.index ["batch_id"], name: "index_good_jobs_on_batch_id", where: "(batch_id IS NOT NULL)"
    t.index ["concurrency_key", "created_at"], name: "index_good_jobs_on_concurrency_key_and_created_at"
    t.index ["concurrency_key"], name: "index_good_jobs_on_concurrency_key_when_unfinished", where: "(finished_at IS NULL)"
    t.index ["cron_key", "created_at"], name: "index_good_jobs_on_cron_key_and_created_at_cond", where: "(cron_key IS NOT NULL)"
    t.index ["cron_key", "cron_at"], name: "index_good_jobs_on_cron_key_and_cron_at_cond", unique: true, where: "(cron_key IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_jobs_on_finished_at_only", where: "(finished_at IS NOT NULL)"
    t.index ["job_class"], name: "index_good_jobs_on_job_class"
    t.index ["labels"], name: "index_good_jobs_on_labels", where: "(labels IS NOT NULL)", using: :gin
    t.index ["locked_by_id"], name: "index_good_jobs_on_locked_by_id", where: "(locked_by_id IS NOT NULL)"
    t.index ["priority", "created_at"], name: "index_good_job_jobs_for_candidate_lookup", where: "(finished_at IS NULL)"
    t.index ["priority", "created_at"], name: "index_good_jobs_jobs_on_priority_created_at_when_unfinished", order: { priority: "DESC NULLS LAST" }, where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at"], name: "index_good_jobs_on_priority_scheduled_at_unfinished_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["queue_name", "scheduled_at"], name: "index_good_jobs_on_queue_name_and_scheduled_at", where: "(finished_at IS NULL)"
    t.index ["scheduled_at"], name: "index_good_jobs_on_scheduled_at", where: "(finished_at IS NULL)"
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

  create_table "strata_determinations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "subject_id", null: false
    t.string "subject_type", null: false
    t.string "decision_method", null: false
    t.string "outcome", null: false
    t.jsonb "determination_data", default: {}, null: false
    t.uuid "determined_by_id"
    t.datetime "determined_at", null: false
    t.datetime "created_at", null: false
    t.string "reasons", default: [], null: false, array: true
    t.index ["created_at"], name: "index_strata_determinations_on_created_at"
    t.index ["determined_at"], name: "index_strata_determinations_on_determined_at"
    t.index ["determined_by_id"], name: "index_strata_determinations_on_determined_by_id"
    t.index ["subject_id", "subject_type"], name: "index_strata_determinations_on_polymorphic_subject"
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
    t.string "role"
    t.string "region"
    t.string "full_name"
    t.index ["uid"], name: "index_users_on_uid", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activities", "activity_report_application_forms"
  add_foreign_key "activity_report_application_forms", "certification_cases"
  add_foreign_key "certification_batch_upload_audit_logs", "certification_batch_uploads"
  add_foreign_key "certification_batch_upload_errors", "certification_batch_uploads"
  add_foreign_key "certification_cases", "certifications"
  add_foreign_key "exemption_application_forms", "certification_cases"
end
