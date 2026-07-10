# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExclusionDeterminationService do
  let(:service) { described_class }
  let(:cert_date) { Date.new(2025, 7, 1) }
  let(:member_data) { build(:certification_member_data, cert_date: cert_date) }
  let(:rating_data) { nil }
  let(:veteran_disability_service) { instance_double(VeteranDisabilityService, get_disability_rating: rating_data) }

  before do
    allow(VeteranDisabilityService).to receive(:new).and_return(veteran_disability_service)
  end

  describe '#determine' do
    let(:certification) do
      create(
        :certification,
        member_data: member_data,
        certification_requirements: build(:certification_certification_requirements, certification_date: cert_date)
      )
    end
    let(:kase) { create(:certification_case, certification_id: certification.id) }

    before do
      allow(Strata::EventManager).to receive(:publish)
      allow(NotificationService).to receive(:send_email_notification)
    end

    # The single Determination recorded on the excluded path (nil when not excluded).
    def recorded_exclusion
      Determination.where(subject: certification, outcome: "excluded").first
    end

    context 'when a single exclusion applies' do
      context 'when the member is American Indian or Alaska Native' do
        let(:member_data) do
          build(:certification_member_data, race_ethnicity: "american_indian_or_alaska_native", cert_date: cert_date)
        end

        it 'publishes DeterminedExcluded and closes the case' do
          service.determine(kase)
          expect(Strata::EventManager).to have_received(:publish).with('DeterminedExcluded', { case_id: kase.id, certification_id: kase.certification_id })
          expect(kase.reload.status).to eq("closed")
        end

        it 'records the AIAN reason code' do
          service.determine(kase)
          expect(recorded_exclusion.reasons).to eq([ "american_indian_alaska_native_excluded" ])
        end
      end

      context 'when the member is pregnant' do
        let(:member_data) { build(:certification_member_data, pregnancy_status: true, cert_date: cert_date) }

        it 'records the pregnancy reason code' do
          service.determine(kase)
          expect(recorded_exclusion.reasons).to eq([ "pregnancy_excluded" ])
        end
      end

      context 'when the member is a veteran with 100% disability' do
        let(:member_data) { build(:certification_member_data, :with_icn, cert_date: cert_date) }
        let(:rating_data) { { "data" => { "attributes" => { "combined_disability_rating" => 100 } } } }

        it 'records the veteran-disability reason code' do
          service.determine(kase)
          expect(recorded_exclusion.reasons).to eq([ "veteran_disability_excluded" ])
        end
      end
    end

    context 'when multiple exclusions apply' do
      # Default priorities: is_american_indian_or_alaska_native (10) < is_veteran_with_disability (30) < is_pregnant (80).
      context 'when pregnant and a veteran with 100% disability' do
        let(:member_data) { build(:certification_member_data, :with_icn, pregnancy_status: true, cert_date: cert_date) }
        let(:rating_data) { { "data" => { "attributes" => { "combined_disability_rating" => 100 } } } }

        it 'records only the higher-priority veteran-disability exclusion' do
          service.determine(kase)
          expect(recorded_exclusion.reasons).to eq([ "veteran_disability_excluded" ])
        end
      end

      context 'when pregnant and American Indian or Alaska Native' do
        let(:member_data) do
          build(:certification_member_data, pregnancy_status: true, race_ethnicity: "american_indian_or_alaska_native", cert_date: cert_date)
        end

        it 'records only the higher-priority AIAN exclusion' do
          service.determine(kase)
          expect(recorded_exclusion.reasons).to eq([ "american_indian_alaska_native_excluded" ])
        end
      end

      context 'when all three exclusions apply' do
        let(:member_data) do
          build(:certification_member_data, :with_icn, pregnancy_status: true, race_ethnicity: "american_indian_or_alaska_native", cert_date: cert_date)
        end
        let(:rating_data) { { "data" => { "attributes" => { "combined_disability_rating" => 100 } } } }

        it 'records exactly one reason code — the highest priority (stop-at-first)' do
          service.determine(kase)
          expect(recorded_exclusion.reasons).to eq([ "american_indian_alaska_native_excluded" ])
        end
      end
    end

    context 'when the configured priority order is overridden' do
      # Re-rank so is_pregnant (10) outranks is_veteran_with_disability (20): proves selection
      # consults Exclusion.priority_order rather than a hardcoded order.
      before do
        allow(Rails.application.config).to receive(:exclusion_types).and_return(
          [
            { id: :is_pregnant, priority: 10 },
            { id: :is_veteran_with_disability, priority: 20 },
            { id: :is_american_indian_or_alaska_native, priority: 30 }
          ]
        )
      end

      let(:member_data) { build(:certification_member_data, :with_icn, pregnancy_status: true, cert_date: cert_date) }
      let(:rating_data) { { "data" => { "attributes" => { "combined_disability_rating" => 100 } } } }

      it 'records the exclusion now ranked highest (pregnancy)' do
        service.determine(kase)
        expect(recorded_exclusion.reasons).to eq([ "pregnancy_excluded" ])
      end
    end

    context 'when a matched exclusion is missing from the priority config' do
      # A fact evaluates true but no configured exclusion declares that fact —
      # exercises the fail-loud drift guard in exclusion_priority.
      before do
        allow(Rails.application.config).to receive(:exclusion_types).and_return(
          [ { id: :is_veteran_with_disability, priority: 30 } ]
        )
      end

      let(:member_data) { build(:certification_member_data, pregnancy_status: true, cert_date: cert_date) }

      it 'raises a descriptive error naming the unbridged fact' do
        expect { service.determine(kase) }.to raise_error(KeyError, /is_pregnant/)
      end
    end

    context 'when no exclusion applies' do
      context 'without any matching condition' do
        let(:member_data) { build(:certification_member_data, race_ethnicity: "white", pregnancy_status: false, cert_date: cert_date) }

        it 'publishes DeterminedNotExcluded and leaves the case open' do
          service.determine(kase)
          expect(Strata::EventManager).to have_received(:publish).with('DeterminedNotExcluded', { case_id: kase.id, certification_id: kase.certification_id })
          expect(kase.reload.status).to eq("open")
        end

        it 'records no exclusion determination' do
          service.determine(kase)
          expect(recorded_exclusion).to be_nil
        end

        it 'logs a denied audit event' do
          expect { service.determine(kase) }
            .to change { Strata::AuditLine.where(subject: certification, actor_type: described_class.name, action: 'case.exclusion.denied').count }.by(1)
        end
      end

      context 'without a 100% veteran disability rating' do
        let(:member_data) { build(:certification_member_data, :with_icn, cert_date: cert_date) }
        let(:rating_data) { { "data" => { "attributes" => { "combined_disability_rating" => 70 } } } }

        it 'publishes DeterminedNotExcluded' do
          service.determine(kase)
          expect(Strata::EventManager).to have_received(:publish).with('DeterminedNotExcluded', { case_id: kase.id, certification_id: kase.certification_id })
        end
      end

      context 'when the VA service returns nil (fail-open)' do
        let(:member_data) { build(:certification_member_data, :with_icn, cert_date: cert_date) }

        it 'publishes DeterminedNotExcluded' do
          service.determine(kase)
          expect(Strata::EventManager).to have_received(:publish).with('DeterminedNotExcluded', { case_id: kase.id, certification_id: kase.certification_id })
        end
      end
    end

    context 'when the member is outside the community-engagement age range' do
      context 'when under 19 with no other exclusion' do
        let(:member_data) { build(:certification_member_data, date_of_birth: cert_date - 18.years, race_ethnicity: "white", pregnancy_status: false, cert_date: cert_date) }

        it 'publishes DeterminedNotExcluded and leaves the case open' do
          service.determine(kase)
          expect(Strata::EventManager).to have_received(:publish).with('DeterminedNotExcluded', { case_id: kase.id, certification_id: kase.certification_id })
          expect(kase.reload.status).to eq("open")
        end
      end

      context 'when 65 or older with no other exclusion' do
        let(:member_data) { build(:certification_member_data, date_of_birth: cert_date - 65.years, race_ethnicity: "white", pregnancy_status: false, cert_date: cert_date) }

        it 'publishes DeterminedNotExcluded' do
          service.determine(kase)
          expect(Strata::EventManager).to have_received(:publish).with('DeterminedNotExcluded', { case_id: kase.id, certification_id: kase.certification_id })
        end
      end
    end
  end
end
