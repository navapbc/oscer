# frozen_string_literal: true

class Activity < ApplicationRecord
  include Strata::Attributes
  ALLOWED_CATEGORIES = ActivityCategories::ALL
  AI_SOURCED_EVIDENCE_SOURCES = [
    ActivityAttributions::AI_ASSISTED,
    ActivityAttributions::AI_ASSISTED_WITH_MEMBER_EDITS
  ].freeze

  NON_AI_EVIDENCE_SOURCES = [
    ActivityAttributions::SELF_REPORTED,
    ActivityAttributions::AI_REJECTED_MEMBER_OVERRIDE
  ].freeze

  EVIDENCE_SOURCES = (AI_SOURCED_EVIDENCE_SOURCES + NON_AI_EVIDENCE_SOURCES).freeze

  has_many_attached :supporting_documents

  default_scope { with_attached_supporting_documents }

  strata_attribute :month, :date
  strata_attribute :name, :string
  strata_attribute :category, :string

  validates :name, presence: true
  validates :category, presence: true, inclusion: { in: ALLOWED_CATEGORIES }
  validates :evidence_source, inclusion: { in: EVIDENCE_SOURCES }, allow_nil: true

  def self_reported?
    evidence_source.nil? || evidence_source == "self_reported"
  end

  def ai_sourced?
    AI_SOURCED_EVIDENCE_SOURCES.include?(evidence_source)
  end
end
