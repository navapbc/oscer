# frozen_string_literal: true

class CertificationBatchUploadError < ApplicationRecord
  belongs_to :certification_batch_upload

  validates :row_number, presence: true, numericality: { greater_than: 0 }
  validates :error_code, presence: true
  validates :error_message, presence: true
end
