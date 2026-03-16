# frozen_string_literal: true

class DocAiConfidenceService
  # Returns confidence for a single activity via batch lookup.
  def confidence_for_activity(activity)
    return nil unless activity.ai_sourced?

    confidence_by_activity_id([ activity.id ])[activity.id]
  end

  # Batch lookup: returns { activity_id => confidence_float_or_nil } for the given IDs.
  # Assumes 1:1 relationship between activity and staged document (one validated doc per activity).
  def confidence_by_activity_id(activity_ids)
    return {} if activity_ids.empty?

    # unscoped bypasses default_scope { with_attached_file } — we only need extracted_fields
    docs = StagedDocument.unscoped.validated.where(
      stageable_type: Activity.polymorphic_name,
      stageable_id: activity_ids
    )

    confidence_by_activity = docs.to_h { |doc| [ doc.stageable_id, doc.average_confidence ] }

    activity_ids.index_with { |id| confidence_by_activity[id] }
  end

  # Returns { case_id => confidence_float_or_nil } for the given case IDs.
  # When a case has multiple AI activities, averages their individual confidences.
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

    # 1:1 activity-to-document: each activity has at most one validated staged document
    activity_confidence = confidence_by_activity_id(activities.map(&:id))

    confidence_by_case = {}
    activities.each do |activity|
      case_id = form_to_case[activity.activity_report_application_form_id]
      next unless case_id

      conf = activity_confidence[activity.id]
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
