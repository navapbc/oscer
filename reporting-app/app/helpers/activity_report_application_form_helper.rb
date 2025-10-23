# frozen_string_literal: true

module ActivityReportApplicationFormHelper
  # Get current selected reporting periods as JSON strings
  # TODO: Update strata-sdk to support setting strata array attributes from date strings (e.g. "2024-01").
  # Linear Issue: TSS-375(https://linear.app/nava-platform/issue/TSS-375/add-ability-to-set-array-attributes)
  # Use datestring when supported: [date.strftime("%B %Y"), date.strftime("%Y-%m")]
  def selected_reporting_periods(activity_report_application_form)
    activity_report_application_form.reporting_periods.map do |rp|
      if rp.is_a?(Strata::YearMonth)
        { year: rp.year, month: rp.month }.to_json
      else
        { year: rp.fetch(:year), month: rp.fetch(:month) }.to_json
      end
    end
  end

  # Generate collection checkbox options for selectable reporting periods
  # TODO: Update strata-sdk to support setting strata array attributes from date strings (e.g. "2024-01")
  # Linear Issue: TSS-375(https://linear.app/nava-platform/issue/TSS-375/add-ability-to-set-array-attributes)
  # Use datestring when supported: [date.strftime("%B %Y"), date.strftime("%Y-%m")]
  def selectable_reporting_periods(months)
    months.map do |date|
      date = date.to_date
      [ date.strftime("%B %Y"), { year: date.year, month: date.month }.to_json ]
    end
  end
end
