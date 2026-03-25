# frozen_string_literal: true

module CertificationBatchUploadsHelper
  UPLOADER_LABEL_API = "API"
  UPLOADER_LABEL_SYSTEM = "System"
  UPLOADER_LABEL_UNKNOWN = "Unknown"

  def status_tag_class(status)
    case status
    when "pending" then ""
    when "processing" then "usa-tag--info"
    when "completed" then "usa-tag--success"
    when "failed" then "usa-tag--error"
    else ""
    end
  end

  def uploader_display_name(batch_upload)
    if batch_upload.ui?
      batch_upload.uploader&.email || UPLOADER_LABEL_UNKNOWN
    elsif batch_upload.api?
      UPLOADER_LABEL_API
    else
      UPLOADER_LABEL_SYSTEM
    end
  end

  # Returns alert options (type, heading, message) for the batch upload's current status,
  # or nil if the status has no alert (e.g. completed, which renders its own partial).
  def status_alert_options(batch_upload)
    scope = "staff.certification_batch_uploads.show"

    case batch_upload.status
    when "pending"
      {
        type: AlertComponent::TYPES::INFO,
        message: t("queued_message", scope: scope)
      }
    when "processing"
      {
        type: AlertComponent::TYPES::INFO,
        message: t(
          "processing_message",
          scope: scope,
          processed: batch_upload.num_rows_processed,
          total: batch_upload.num_rows
        )
      }
    when "failed"
      {
        type: AlertComponent::TYPES::ERROR,
        heading: t("failed_heading", scope: scope),
        message: batch_upload.results&.dig("error") || t("failed_message", scope: scope)
      }
    end
  end
end
