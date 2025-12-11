# frozen_string_literal: true

class Activity < ApplicationRecord
  include Strata::Attributes
  ALLOWED_CATEGORIES = ActivityCategories::ALL

  has_many_attached :supporting_documents

  default_scope { with_attached_supporting_documents }

  strata_attribute :month, :date
  strata_attribute :name, :string
  strata_attribute :category, :string

  validates :name, presence: true
  validates :category, presence: true, inclusion: { in: ALLOWED_CATEGORIES }
end
