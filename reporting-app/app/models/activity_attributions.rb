# frozen_string_literal: true

# Shared activity attribution labels used to track the source of activity data.
module ActivityAttributions
  AI_ASSISTED = "ai_assisted" # Member uploaded, AI extracted
  AI_ASSISTED_WITH_MEMBER_EDITS = "ai_assisted_with_member_edits" # Member uploaded, AI extracted, member corrected before submission
  AI_REJECTED_MEMBER_OVERRIDE = "ai_rejected_member_override" # DocAI rejected document, member proceeded anyway
  STATE_PROVIDED = "state_provided" # Data from external data sources
  SELF_REPORTED = "self_reported" # Member manually entered and uploaded without Doc AI
end
