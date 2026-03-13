# frozen_string_literal: true

class PayslipToIncomeActivityCreateService
  class PayslipNotInReportingPeriodError < StandardError; end

  PAYSLIP_DOC_CLASS = "Payslip"
  private_constant :PAYSLIP_DOC_CLASS

  def initialize(form:)
    @form = form
  end

  def call(staged_document_ids)
    eligible_docs = StagedDocument.where(
      id: staged_document_ids,
      status: :validated,
      doc_ai_matched_class: PAYSLIP_DOC_CLASS,
      stageable_id: nil
      )

    return [] if eligible_docs.empty?

    activities = eligible_docs.map { |doc| build_activity(doc) }

    Activity.transaction do
      activities.each { |activity| activity.save!(validate: false) }

      eligible_docs.zip(activities).each do |doc, activity|
        ActiveStorage::Attachment.create!(
          name: "supporting_documents",
          record_type: activity.class.polymorphic_name,
          record_id: activity.id,
          blob_id: doc.file.blob.id
        )
        doc.update!(stageable: activity)
      end
    end

    activities
  end

  private

  def build_activity(staged_document)
    payslip = DocAiResult.from_response(
      "matchedDocumentClass" => staged_document.doc_ai_matched_class,
      "fields" => staged_document.extracted_fields,
      "status" => "completed"
    )

    month = derive_month(payslip.pay_period_start_date&.value)
    raise PayslipNotInReportingPeriodError, "Payslip date is not within the reporting period" if month.nil?

    IncomeActivity.new(
      activity_report_application_form_id: @form.id,
      category: "employment",
      evidence_source: ActivityAttributions::AI_ASSISTED,
      month: month,
      income: income_cents(payslip)
    )
  end

  def income_cents(payslip)
    value = payslip.current_gross_pay&.value
    return nil if value.nil?

    (value.to_f * 100).round
  end

  def derive_month(pay_period_start_date)
    reporting_dates = @form.reporting_period_dates
    return nil if pay_period_start_date.nil?

    begin
      date = Date.parse(pay_period_start_date.to_s)
      reporting_dates.find { |d| d.year == date.year && d.month == date.month }
    rescue ArgumentError, Date::Error
      nil
    end
  end
end
