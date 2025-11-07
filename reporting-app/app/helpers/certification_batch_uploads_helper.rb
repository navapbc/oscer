# frozen_string_literal: true

module CertificationBatchUploadsHelper
  def status_tag_class(status)
    case status
    when "pending" then ""
    when "processing" then "usa-tag--info"
    when "completed" then "usa-tag--success"
    when "failed" then "usa-tag--error"
    else ""
    end
  end
end
