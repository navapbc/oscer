# frozen_string_literal: true

class Api::CertificationBatchUploads::CreateRequest < ValueObject
  attribute :signed_blob_id, :string

  validates :signed_blob_id, presence: true

  def self.from_request_params(params)
    new_filtered(params)
  end
end
