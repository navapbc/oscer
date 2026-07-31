# frozen_string_literal: true

require "rails_helper"

# Reachability guard for the trailing verification_data_source_check step (OSCER-805). Drives the
# real cascade from certification creation through the real registry, stubbing nothing in the
# determination path, so a source that starves another one fails here.
#
# Exists because a mock keyed off va_icn was starved by another consulted at the earlier exclusion
# step, leaving its branch dead. No unit spec could catch that: each adapter's rule was correct in
# isolation, certification_business_process_spec stubs DataSourceCheckService outright, and the
# orchestrator's real-registry cases start from a Certification, so they never traverse
# ExclusionDeterminationService. The failure existed only in the composition of stages.
RSpec.describe CertificationBusinessProcess, type: :business_process do
  before do
    # Outbound email only — nothing in the determination path is stubbed.
    allow(NotificationService).to receive(:send_email_notification)
  end

  # A member with no exclusion signals, no in-hand exception signals and no activities,
  # so the cascade reaches the trailing step rather than terminating in-hand.
  def drive(va_icn:, email: "member@example.com")
    certification = create(:certification, member_data: build(
      :certification_member_data, va_icn: va_icn, account_email: email
    ))

    {
      step: CertificationCase.find_by(certification_id: certification.id)&.business_process_current_step,
      determinations: Strata::Determination.where(subject_id: certification.id).order(:determined_at).to_a
    }
  end

  def sole_determination(outcome)
    expect(outcome[:determinations].size).to eq(1)
    outcome[:determinations].first
  end

  let(:trigger) { Verification::Adapters::MockCommunityEngagement::TRIGGER_EMAIL_SUBSTRING }
  let(:ce_email) { "member+#{trigger}@example.com" }

  describe "the exclusion step (consulted before the orchestrator)" do
    it "records an exclusion for a va_icn last digit divisible by 3" do
      outcome = drive(va_icn: "1000000003")
      determination = sole_determination(outcome)

      expect(outcome[:step]).to eq(CertificationBusinessProcess::END_STEP)
      expect(determination.outcome).to eq("excluded")
      expect(determination.determination_data).to include("data_source" => "mock_drug_treatment")
    end

    it "records an exception for an odd va_icn last digit not divisible by 3" do
      outcome = drive(va_icn: "1000000007")
      determination = sole_determination(outcome)

      expect(outcome[:step]).to eq(CertificationBusinessProcess::END_STEP)
      expect(determination.outcome).to eq("excepted")
      expect(determination.determination_data).to include("data_source" => "mock_drug_treatment")
    end
  end

  describe "the verification_data_source_check step" do
    it "records a source-attested exception for an even va_icn last digit" do
      outcome = drive(va_icn: "1000000002")
      determination = sole_determination(outcome)

      expect(outcome[:step]).to eq(CertificationBusinessProcess::END_STEP)
      expect(determination.outcome).to eq("excepted")
      expect(determination.determination_data).to include("data_source" => "mock_emergency_county")
    end

    it "records a source-attested community engagement for a triggering email" do
      outcome = drive(va_icn: "1000000X", email: ce_email)
      determination = sole_determination(outcome)

      expect(outcome[:step]).to eq(CertificationBusinessProcess::END_STEP)
      expect(determination.outcome).to eq("compliant")
      expect(determination.reasons).to eq([ "hours_reported_compliant" ])
      expect(determination.determination_data).to include(
        "data_source" => "mock_community_engagement",
        "calculation_type" => Determination::CALCULATION_TYPE_DATA_SOURCE_CE
      )
    end

    it "records the negative determination and routes to report_activities when no source matches" do
      outcome = drive(va_icn: "1000000X")
      determination = sole_determination(outcome)

      expect(outcome[:step]).to eq(CertificationBusinessProcess::REPORT_ACTIVITIES_STEP)
      expect(determination.outcome).to eq("not_compliant")
      expect(determination.determination_data).to include(
        "calculation_type" => Determination::CALCULATION_TYPE_EXTERNAL_CE_COMBINED
      )
    end

    it "records exactly one determination on the negative path" do
      # The negative moved from the community-engagement check to this step precisely so a
      # member cannot end up with a superseded not_compliant row plus a later exception.
      expect(drive(va_icn: "1000000X")[:determinations].size).to eq(1)
    end
  end

  # The guard itself. Stated over the live registry rather than a hardcoded list, so
  # registering a new order-bearing source without a reachable demo case fails here.
  describe "every enabled order-bearing source is reachable" do
    let(:order_bearing_ids) do
      Rails.application.config.verification_data_sources
        .select { |entry| entry[:enabled] && entry[:order] }
        .map { |entry| entry[:id].to_s }
    end

    it "credits each one in at least one demonstrable path" do
      credited = [
        drive(va_icn: "1000000002"),
        drive(va_icn: "1000000X", email: ce_email)
      ].flat_map { |outcome| outcome[:determinations] }
        .map { |determination| determination.determination_data["data_source"] }
        .compact
        .uniq

      expect(credited).to include(*order_bearing_ids)
    end
  end
end
