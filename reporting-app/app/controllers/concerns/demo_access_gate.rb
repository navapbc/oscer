# frozen_string_literal: true

# Gates demo tooling controllers so they are unreachable in deployed
# environments unless explicitly enabled.
#
# The demo UI creates real Certification records via the production
# Certifications::CreationService and has no authentication, so it must fail
# closed everywhere except:
#   - local development / test (Rails.env.local? — development and test), or
#   - environments where FEATURE_DEMO_CERTIFICATIONS is explicitly enabled.
#
# When neither condition holds, requests return 404 as if the route did not
# exist.
module DemoAccessGate
  extend ActiveSupport::Concern

  included do
    before_action :ensure_demo_certifications_enabled
  end

  # Shared gate predicate for controller before_actions and route constraints.
  def self.access_allowed?
    Features.demo_certifications_enabled? || Rails.env.local?
  end

  private

  def ensure_demo_certifications_enabled
    return if DemoAccessGate.access_allowed?

    head :not_found
  end
end
