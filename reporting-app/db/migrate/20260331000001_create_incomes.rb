# frozen_string_literal: true

class CreateIncomes < ActiveRecord::Migration[7.2]
  def change
    create_table :incomes, id: :uuid, comment: "Income data from external sources (API/batch/QWD) for compliance calculation" do |t|
      t.string :member_id, null: false,
               comment: "Member reference - always required (parallel to ExParteActivity; no certification FK)"
      t.string :category, null: false,
               comment: "Activity category: employment, community_service, education"
      t.decimal :gross_income, precision: 10, scale: 2, null: false,
                comment: "Gross income for the pay period"
      t.date :period_start, null: false,
             comment: "Pay period start date"
      t.date :period_end, null: false,
             comment: "Pay period end date"
      t.string :source_type, null: false,
               comment: "Source type: api, quarterly_wage_data, or batch_upload"
      t.string :source_id,
               comment: "Source record ID (e.g., batch upload ID)"
      t.datetime :reported_at, null: false,
                 comment: "When the income data was reported"
      t.jsonb :metadata, default: {}, null: false,
              comment: "Additional structured fields (e.g., employer name)"
      t.timestamps
    end

    add_index :incomes, :member_id,
              name: "index_incomes_on_member_id",
              comment: "Lookup entries by member"
    add_index :incomes, [ :source_type, :source_id ],
              name: "index_incomes_on_source",
              comment: "Source tracking (batch upload lookups)"
    add_index :incomes, [ :period_start, :period_end ],
              name: "index_incomes_on_period",
              comment: "Date range queries"
  end
end
