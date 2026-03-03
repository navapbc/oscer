# frozen_string_literal: true

class StagedDocument < ApplicationRecord
  belongs_to :stageable, polymorphic: true, optional: true

  has_one_attached :file

  enum :status, {
    pending:   "pending",   # file received, DocAI not yet called
    validated: "validated", # DocAI returned a recognised income document (Payslip or W2)
    rejected:  "rejected",  # DocAI returned unrecognised document type or validation failure
    failed:    "failed"     # DocAI service error (graceful degradation)
  }

  validates :status, presence: true
  validates :file, attached: true
  validates :user_id, presence: true

  default_scope { with_attached_file }
end
