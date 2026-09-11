# frozen_string_literal: true

module ActivitiesHelper
  EVIDENCE_SOURCE_ICONS = {
    ActivityAttributions::SELF_REPORTED => { icon: "person", color: "text-primary" },
    ActivityAttributions::AI_ASSISTED => { icon: "insights", color: "text-gold" },
    ActivityAttributions::AI_ASSISTED_WITH_MEMBER_EDITS => { icon: "edit", color: "text-green" },
    ActivityAttributions::AI_REJECTED_MEMBER_OVERRIDE => { icon: "warning", color: "text-error" }
  }.freeze

  ATTRIBUTION_FIELD_CLASSES = {
    ActivityAttributions::SELF_REPORTED => "bg-attribution-primary",
    ActivityAttributions::AI_ASSISTED => "bg-attribution-gold",
    ActivityAttributions::AI_ASSISTED_WITH_MEMBER_EDITS => "bg-attribution-green",
    ActivityAttributions::AI_REJECTED_MEMBER_OVERRIDE => "border-1px border-error bg-attribution-error"
  }.freeze

  def attribution_field_classes(evidence_source)
    source = evidence_source || ActivityAttributions::SELF_REPORTED
    ATTRIBUTION_FIELD_CLASSES.fetch(source, "")
  end

  def evidence_source_icon(evidence_source)
    source = evidence_source || ActivityAttributions::SELF_REPORTED
    # Fall back both the icon config AND the source key for i18n lookup
    source = ActivityAttributions::SELF_REPORTED unless EVIDENCE_SOURCE_ICONS.key?(source)
    icon_config = EVIDENCE_SOURCE_ICONS[source]

    {
      icon: icon_config[:icon],
      color: icon_config[:color],
      label: I18n.t(source, scope: "activities.evidence_sources")
    }
  end

  # Returns per-field evidence source for an AI-sourced activity by comparing
  # current values to the original AI-extracted values from StagedDocument.
  # Fields not extracted by AI (category, reporting_method) are always self_reported.
  # For IncomeActivity, employer name is compared when DocAI supplies `companyname`.
  # Returns a hash of { field_name => evidence_source_string }.
  def field_attributions(activity, staged_document)
    base = ActivityAttributions::SELF_REPORTED
    result = {
      category: base,
      reporting_method: base,
      name: base
    }

    return result.merge(month: base, income: base, hours: base) unless activity.ai_sourced? && staged_document

    original = original_ai_values(activity, staged_document)

    result[:month] = field_attribution_for(activity.month, original[:month])
    if activity.is_a?(IncomeActivity)
      result[:income] = field_attribution_for(activity.income&.cents, original[:income_cents])
      result[:name] = field_attribution_for(
        DocAiResult::Payslip.normalize_company_name_string(activity.name),
        original[:name]
      )
    else
      # AI (payslip extraction) never populates hours — only income and month.
      # Hours on an AI-sourced activity are always self-reported.
      result[:hours] = base
    end

    result
  end

  # Returns the attributed_field partial locals for a specific field's evidence source.
  def attribution_locals_for(evidence_source)
    icon_info = evidence_source_icon(evidence_source)
    {
      field_classes: attribution_field_classes(evidence_source),
      icon_info: icon_info,
      attribution_label: icon_info[:label]
    }
  end

  def confidence_display(confidence)
    return nil if confidence.nil?

    percentage = (confidence * 100).round
    threshold_percentage = (Rails.application.config.doc_ai[:low_confidence_threshold] * 100).round
    {
      percentage: percentage,
      low: percentage < threshold_percentage
    }
  end

  def confidence_cell_content(activity, confidence_by_activity)
    return confidence_value_content(nil) unless confidence_by_activity && activity.ai_sourced?

    conf = confidence_display(confidence_by_activity[activity.id])
    confidence_value_content(conf)
  end

  def confidence_value_content(conf)
    return "—" if conf.nil?

    parts = []
    if conf[:low]
      parts << uswds_icon("warning", label: I18n.t("activities.confidence.low_label"), css_class: "text-error", style: "vertical-align: middle")
    end
    parts << "#{conf[:percentage]}%"
    safe_join(parts, " ")
  end

  def task_confidence(case_id, confidence_by_case)
    return { conf: nil, low: false } unless confidence_by_case

    conf = confidence_display(confidence_by_case[case_id])
    { conf: conf, low: conf&.dig(:low) || false }
  end

  private

  def field_attribution_for(current_value, original_value)
    if current_value == original_value
      ActivityAttributions::AI_ASSISTED
    else
      ActivityAttributions::AI_ASSISTED_WITH_MEMBER_EDITS
    end
  end

  def original_ai_values(activity, staged_document)
    fields = staged_document.extracted_fields
    payslip = DocAiResult.from_response(
      "matchedDocumentClass" => staged_document.doc_ai_matched_class,
      "fields" => fields,
      "status" => "completed"
    )

    month = parse_ai_month(payslip.pay_period_start_date&.value)
    income_cents = payslip.current_gross_pay&.value&.then { |v| (v.to_f * 100).round }

    name = payslip.is_a?(DocAiResult::Payslip) ? payslip.company_name_value : nil

    { month: month, income_cents: income_cents, hours: nil, name: name }
  end

  def parse_ai_month(pay_period_start_date)
    return nil if pay_period_start_date.nil?

    date = Date.parse(pay_period_start_date.to_s)
    Date.new(date.year, date.month, 1)
  rescue ArgumentError, Date::Error
    nil
  end
end
