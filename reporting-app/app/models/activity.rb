# frozen_string_literal: true

class Activity < ApplicationRecord
  include Strata::Attributes

  has_many_attached :supporting_documents

  default_scope { with_attached_supporting_documents }

  strata_attribute :month, :date
  strata_attribute :hours, :decimal
  strata_attribute :name, :string

  validates :name, presence: true
  validates :hours, presence: true, numericality: { greater_than: 0 }
end
