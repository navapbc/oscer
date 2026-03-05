# frozen_string_literal: true

class Api::CertificationBatchUploads::Response < ValueObject
  attribute :id, :string
  attribute :status, :string
  attribute :filename, :string
  attribute :source_type, :string
  attribute :num_rows, :integer
  attribute :num_rows_processed, :integer
  attribute :num_rows_succeeded, :integer
  attribute :num_rows_errored, :integer
  attribute :created_at, :datetime
  attribute :updated_at, :datetime
  attribute :processed_at, :datetime

  def self.from_batch_upload(batch_upload)
    new_filtered(batch_upload)
  end
end
