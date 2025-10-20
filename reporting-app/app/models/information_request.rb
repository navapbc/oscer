# frozen_string_literal: true

class InformationRequest < ApplicationRecord
  include Strata::Attributes

  has_many_attached :supporting_documents

  strata_attribute :application_form_id, :uuid
  strata_attribute :application_form_type, :string
  strata_attribute :due_date, :date
  strata_attribute :member_comment, :text
  strata_attribute :staff_comment, :text

  before_create :set_due_date

  validates :staff_comment, presence: true

  default_scope { with_attached_supporting_documents }
  scope :for_application_forms, ->(application_form_ids) { where(application_form_id: application_form_ids) }

  private

  # TODO: update set_due_date to not be hardcoded
  def set_due_date
    self.due_date ||= 7.days.from_now.to_date
  end
end
