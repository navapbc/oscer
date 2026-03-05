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
end
