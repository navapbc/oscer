# frozen_string_literal: true

# Tracks the source/origin of how a certification was created
# Supports multiple source types: batch_upload, manual, api, etc.
class CertificationOrigin < ApplicationRecord
  # Source types
  SOURCE_TYPE_BATCH_UPLOAD = "batch_upload"
  SOURCE_TYPE_MANUAL = "manual"
  SOURCE_TYPE_API = "api"

  validates :certification_id, presence: true, uniqueness: true
  validates :source_type, presence: true, inclusion: { in: [ SOURCE_TYPE_BATCH_UPLOAD, SOURCE_TYPE_MANUAL, SOURCE_TYPE_API ] }

  # Polymorphic-style accessors (without actual polymorphic association)
  # This avoids coupling to specific source models

  # Get certifications by source
  scope :from_batch_upload, ->(batch_upload_id) { where(source_type: SOURCE_TYPE_BATCH_UPLOAD, source_id: batch_upload_id) }
  scope :manual_entries, -> { where(source_type: SOURCE_TYPE_MANUAL) }
  scope :from_api, -> { where(source_type: SOURCE_TYPE_API) }

  # Helper to check source type
  def batch_upload?
    source_type == SOURCE_TYPE_BATCH_UPLOAD
  end

  def manual?
    source_type == SOURCE_TYPE_MANUAL
  end

  def api?
    source_type == SOURCE_TYPE_API
  end

  # Get the source object (if needed)
  def source
    return unless source_id

    case source_type
    when SOURCE_TYPE_BATCH_UPLOAD
      CertificationBatchUpload.find_by(id: source_id)
      # Add other types as needed
    end
  end
end
