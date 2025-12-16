# frozen_string_literal: true

class ReviewExemptionClaimTask < OscerTask
  def self.application_form_class
    ExemptionApplicationForm
  end
end
