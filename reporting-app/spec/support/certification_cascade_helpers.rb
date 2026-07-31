# frozen_string_literal: true

# Settles the determination cascade that runs when a certification factory commits, so a
# factory-created case lands on report_activities instead of closing itself compliant.
#
# Both stubs are required: since OSCER-805 the community-engagement check's not-met branch only
# publishes the internal routing event, and the trailing step owns the member-facing negative.
# Stubbing either alone leaves the bootstrap case mid-cascade.
module CertificationCascadeHelpers
  def stub_cascade_to_report_activities
    allow(CommunityEngagementCheckService).to receive(:determine) do |kase|
      Strata::EventManager.publish("DeterminedCommunityEngagementNotMet", {
        case_id: kase.id,
        certification_id: kase.certification_id
      })
    end

    allow(DataSourceCheckService).to receive(:determine) do |kase|
      Strata::EventManager.publish("DeterminedCommunityEngagementActionRequired", {
        case_id: kase.id,
        certification_id: kase.certification_id
      })
    end
  end
end

RSpec.configure do |config|
  config.include CertificationCascadeHelpers
end
