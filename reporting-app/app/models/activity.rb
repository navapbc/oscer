# frozen_string_literal: true

class Activity < ApplicationRecord
  include Strata::Attributes

  has_many_attached :supporting_documents

  default_scope { with_attached_supporting_documents }

  strata_attribute :month, :date
  strata_attribute :name, :string

  validates :name, presence: true
end
