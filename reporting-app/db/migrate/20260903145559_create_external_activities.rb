# frozen_string_literal: true

# Consolidates external_hourly_activities and external_income_activities into one table where a
# row reports hours, gross income, or both. The two old tables are left in place; backfilling and
# dropping them is a separate task.
class CreateExternalActivities < ActiveRecord::Migration[8.0]
  def change
    create_table :external_activities, id: :uuid, default: -> { "gen_random_uuid()" },
                 comment: "Hours and/or gross income data from external sources (API/batch) for compliance calculation" do |t|
      t.string   :member_id, null: false,
                 comment: "Member reference - always required (no certification FK; the member's active certification is implicit)"
      t.string   :category, null: false,
                 comment: "Activity category: employment, community_service, education, unearned, or household (household income only)"
      t.string   :name, comment: "Reported name of the school, organization, or person"
      t.decimal  :hours, precision: 8, scale: 2,
                 comment: "Hours worked/volunteered for the period; null when the row reports income only"
      t.decimal  :gross_income, precision: 10, scale: 2,
                 comment: "Gross income for the period; null when the row reports hours only"
      t.date     :period_start, null: false, comment: "Activity period start date"
      t.date     :period_end, null: false, comment: "Activity period end date"
      t.string   :source_type, null: false, comment: "Source type: 'api' or 'batch_upload'"
      t.string   :source_id, comment: "Source record ID (e.g., batch upload ID)"
      t.datetime :reported_at, null: false, comment: "When the external source reported this data"
      t.jsonb    :metadata, default: {}, null: false,
                 comment: "Additional structured fields (e.g., employer name)"
      t.string   :origin_hash,
                 comment: "Fingerprint of the submission this row was split from; shared by every monthly row of one submission (not unique)"
      t.timestamps

      t.index :member_id, comment: "Lookup entries by member"
      t.index :origin_hash
      t.index [ :period_start, :period_end ], name: "index_external_activities_on_period",
              comment: "Date range queries"
      t.index [ :source_type, :source_id ], name: "index_external_activities_on_source",
              comment: "Source tracking (batch upload lookups)"

      t.check_constraint "hours IS NOT NULL OR gross_income IS NOT NULL",
                         name: "external_activities_hours_or_income"
    end
  end
end
