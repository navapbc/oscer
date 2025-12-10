# frozen_string_literal: true

class CreateExParteActivities < ActiveRecord::Migration[7.2]
  def change
    create_table :ex_parte_activities, id: :uuid, comment: "Hours data from external sources (API/batch) for compliance calculation" do |t|
      t.string :member_id, null: false,
               comment: "Member reference - always required (allows hours-first save order)"
      t.uuid :certification_id,
             comment: "Certification reference - nullable for pending entries before cert creation"
      t.string :category, null: false,
               comment: "Activity category: employment, community_service, education"
      t.decimal :hours, precision: 8, scale: 2, null: false,
                comment: "Hours worked/volunteered (max 744 = 31 days × 24 hours)"
      t.date :period_start, null: false,
             comment: "Activity period start date"
      t.date :period_end, null: false,
             comment: "Activity period end date"
      t.boolean :outside_period, default: false, null: false,
                comment: "True if activity dates are outside certification lookback period"
      t.string :source_type, null: false,
               comment: "Source type: 'api' or 'batch_upload'"
      t.uuid :source_id,
             comment: "Source record ID (e.g., HoursDataBatchUpload ID for batch_upload)"
      t.datetime :reported_at, null: false,
                 comment: "When the data was submitted"
      t.jsonb :metadata, default: {},
              comment: "Additional context (employer, verification_status, etc.)"
      t.timestamps
    end

    add_index :ex_parte_activities, :member_id,
              name: "index_ex_parte_activities_on_member_id",
              comment: "Lookup entries by member (for pending entry lookups)"
    add_index :ex_parte_activities, :certification_id,
              name: "index_ex_parte_activities_on_certification_id",
              comment: "Lookup entries by certification"
    add_index :ex_parte_activities, [ :source_type, :source_id ],
              name: "index_ex_parte_activities_on_source",
              comment: "Source tracking (batch upload lookups)"
    add_index :ex_parte_activities, [ :period_start, :period_end ],
              name: "index_ex_parte_activities_on_period",
              comment: "Date range queries"
    add_index :ex_parte_activities, :reported_at,
              name: "index_ex_parte_activities_on_reported_at",
              comment: "Sorting by submission time"
    add_index :ex_parte_activities, [ :member_id, :certification_id ],
              where: "certification_id IS NULL",
              name: "idx_ex_parte_activities_pending",
              comment: "Partial index for pending entries (certification_id IS NULL)"
    add_index :ex_parte_activities, :outside_period,
              name: "index_ex_parte_activities_on_outside_period",
              comment: "Filter by outside_period flag"

    add_foreign_key :ex_parte_activities, :certifications,
                    column: :certification_id,
                    on_delete: :nullify
  end
end
