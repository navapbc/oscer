# frozen_string_literal: true

class ActivityReportApplicationFormService
  def self.update_application_form(application_form, params, certification)
    new(application_form, params, certification).call
  end

  def initialize(application_form, params, certification)
    @application_form = application_form
    @application_form.assign_attributes(params)

    @allowed_months = parse_allowed_months(certification)
    @required_count = certification.certification_requirements.number_of_months_to_certify
  end

  def call
    return { success: false, activity_report_application_form: @application_form } unless valid?

    { success: @application_form.save, activity_report_application_form: @application_form }
  end

  private

  def valid?
    validate_count && validate_allowed_months
  end

  def validate_count
    return true if @application_form.reporting_periods.count == @required_count

    @application_form.errors.add(:base, "You must select exactly #{@required_count} months to certify.")
    false
  end

  def validate_allowed_months
    selected = @application_form.reporting_periods.map { |rp| Strata::YearMonth.new(year: rp.fetch(:year), month: rp.fetch(:month)).to_s }
    invalid = selected - @allowed_months

    return true if invalid.empty?

    @application_form.errors.add(:base, "The selected months #{invalid.join(', ')} are not valid for certification.")
    false
  end

  def parse_allowed_months(certification)
    certification.certification_requirements.months_that_can_be_certified.map do |date|
      Strata::YearMonth.new(year: date.year, month: date.month).to_s
    end
  end
end
