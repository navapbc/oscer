# frozen_string_literal: true

# The most recent determination for a subject. Determination carries a default_scope order, so
# reads unscope it before ordering by created_at. Extracted from identical defs previously repeated
# in certification_case_spec (twice), community_engagement_check_service_spec and
# data_source_check_service_spec.
module DeterminationHelpers
  def latest_determination_for(certification_id)
    Determination.unscope(:order).where(subject_id: certification_id).order(created_at: :desc).first
  end
end

RSpec.configure do |config|
  config.include DeterminationHelpers
end
