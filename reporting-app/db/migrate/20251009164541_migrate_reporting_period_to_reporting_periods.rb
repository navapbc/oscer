# frozen_string_literal: true

class MigrateReportingPeriodToReportingPeriods < ActiveRecord::Migration[7.2]
  def up
    # Migrate existing reporting_period values to reporting_periods array using raw SQL
    execute <<-SQL
      UPDATE activity_report_application_forms#{' '}
      SET reporting_periods = JSON_BUILD_ARRAY(
        JSON_BUILD_OBJECT(
          'year', EXTRACT(YEAR FROM reporting_period)::integer,
          'month', EXTRACT(MONTH FROM reporting_period)::integer
        )
      )
      WHERE reporting_period IS NOT NULL;
    SQL
  end

  def down
    # Migrate back from reporting_periods to reporting_period (first element only)
    execute <<-SQL
      UPDATE activity_report_application_forms#{' '}
      SET reporting_period = MAKE_DATE(
        (reporting_periods->0->>'year')::integer,
        (reporting_periods->0->>'month')::integer,
        1
      )
      WHERE reporting_periods IS NOT NULL#{' '}
        AND JSONB_ARRAY_LENGTH(reporting_periods) > 0
        AND reporting_periods->0->>'year' IS NOT NULL
        AND reporting_periods->0->>'month' IS NOT NULL;
    SQL
  end
end
