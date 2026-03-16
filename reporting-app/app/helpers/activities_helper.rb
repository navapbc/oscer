# frozen_string_literal: true

module ActivitiesHelper
  EVIDENCE_SOURCE_ICONS = {
    ActivityAttributions::SELF_REPORTED => { icon: "person", color: "text-primary" },
    ActivityAttributions::AI_ASSISTED => { icon: "insights", color: "text-gold" },
    ActivityAttributions::AI_ASSISTED_WITH_MEMBER_EDITS => { icon: "edit", color: "text-green" },
    ActivityAttributions::AI_REJECTED_MEMBER_OVERRIDE => { icon: "warning", color: "text-error" }
  }.freeze

  def evidence_source_icon(evidence_source)
    source = evidence_source || "self_reported"
    # Fall back both the icon config AND the source key for i18n lookup
    source = "self_reported" unless EVIDENCE_SOURCE_ICONS.key?(source)
    icon_config = EVIDENCE_SOURCE_ICONS[source]

    {
      icon: icon_config[:icon],
      color: icon_config[:color],
      label: I18n.t(source, scope: "activities.evidence_sources")
    }
  end

  def confidence_display(confidence)
    return nil if confidence.nil?

    threshold = Rails.application.config.doc_ai[:low_confidence_threshold]
    {
      percentage: (confidence * 100).round,
      low: confidence < threshold
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
end
