# frozen_string_literal: true

class DocAiConfidenceService
  def confidence_for_activity(activity)
    return nil unless activity.ai_sourced?

    # unscoped bypasses default_scope { with_attached_file } — we only need extracted_fields
    docs = StagedDocument.unscoped.validated.where(stageable_type: Activity.polymorphic_name, stageable_id: activity.id)
    confidences = docs.filter_map(&:average_confidence)
    return nil if confidences.empty?

    (confidences.sum / confidences.size).round(2)
  end

  def confidence_by_case_id(case_ids)
    return {} if case_ids.empty?

    # unscoped bypasses default_scope eager-loads on each model
    forms = ActivityReportApplicationForm.unscoped.where(certification_case_id: case_ids)
    form_to_case = forms.to_h { |f| [ f.id, f.certification_case_id ] }

    activities = Activity.unscoped.where(
      activity_report_application_form_id: forms.select(:id),
      evidence_source: Activity::AI_SOURCED_EVIDENCE_SOURCES
    )
    return case_ids.index_with { nil } if activities.empty?

    docs = StagedDocument.unscoped.validated.where(
      stageable_type: Activity.polymorphic_name,
      stageable_id: activities.select(:id)
    )

    doc_confidences_by_activity = docs.group_by(&:stageable_id).transform_values do |activity_docs|
      confidences = activity_docs.filter_map(&:average_confidence)
      confidences.empty? ? nil : (confidences.sum / confidences.size).round(2)
    end

    confidence_by_case = {}
    activities.each do |activity|
      case_id = form_to_case[activity.activity_report_application_form_id]
      next unless case_id

      conf = doc_confidences_by_activity[activity.id]
      next unless conf

      confidence_by_case[case_id] ||= []
      confidence_by_case[case_id] << conf
    end

    case_ids.index_with do |case_id|
      confs = confidence_by_case[case_id]
      next nil unless confs

      (confs.sum / confs.size).round(2)
    end
  end
end
