# frozen_string_literal: true

class ExemptionInformationRequest < InformationRequest
  def self.task_class
    ReviewExemptionClaimTask
  end
end
