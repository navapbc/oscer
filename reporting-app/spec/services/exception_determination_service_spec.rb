# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExceptionDeterminationService do
  let(:service) { described_class }
  let(:certification) { create(:certification) }
  let(:kase) { create(:certification_case, certification_id: certification.id) }

  before do
    allow(Strata::EventManager).to receive(:publish)
    allow(NotificationService).to receive(:send_email_notification)
  end

  # A verified API exemption of +type+, the shape every check reads. Periods are optional
  # because former_foster_care is presence-only.
  def exemption(type, periods: nil, value: true, verification_status: 'verified')
    { type:, value:, verification_status:, periods: }
  end

  # Each check's member data is set up in its own context; these shared examples assert the common
  # excepted / not-excepted outcomes.
  shared_examples 'an applied external exception' do |reason_code|
    it 'records an excepted determination carrying the reason code' do
      expect { service.determine(kase) }.to change {
        Determination.where(subject: certification, outcome: 'excepted').count
      }.by(1)

      determination = Determination.where(subject: certification, outcome: 'excepted').first
      expect(determination.reasons).to eq([ reason_code ])
    end

    it 'closes the case' do
      service.determine(kase)
      expect(kase.reload.status).to eq('closed')
    end

    it 'publishes DeterminedExcepted' do
      service.determine(kase)
      expect(Strata::EventManager).to have_received(:publish)
        .with('DeterminedExcepted', { case_id: kase.id, certification_id: kase.certification_id })
    end
  end

  shared_examples 'a failed check' do
    it 'does not except the member (publishes DeterminedNotExcepted)' do
      service.determine(kase)
      expect(Strata::EventManager).to have_received(:publish)
        .with('DeterminedNotExcepted', { case_id: kase.id, certification_id: kase.certification_id })
    end

    it 'does not record an exception determination' do
      expect { service.determine(kase) }.not_to change {
        Determination.where(subject: certification, outcome: 'excepted').count
      }
    end
  end

  shared_examples 'a disabled optional exception' do |exception_id|
    before do
      # Default to the real config, then disable only the exception under test, so the checks that
      # run before it (up to the first success) still consult real enablement.
      allow(ExternalException).to receive(:enabled?).and_call_original
      allow(ExternalException).to receive(:enabled?).with(exception_id).and_return(false)
    end

    it_behaves_like 'a failed check'
  end

  shared_examples 'a disabled mandatory exception' do |exception_id|
    before do
      # Default to the real config, then disable only the exception under test, so the checks that
      # run before it (up to the first success) still consult real enablement.
      allow(ExternalException).to receive(:enabled?).and_call_original
      allow(ExternalException).to receive(:enabled?).with(exception_id).and_return(false)
    end

    it_behaves_like 'an applied external exception', "#{exception_id}_excepted"
  end

  # The checks that except a member when the exemption's own period covers a certifiable month.
  # +disabled_behavior+ names the shared example asserting whether disabling the exception in
  # config suppresses the check: optional exceptions gate on it, mandatory ones ignore it.
  shared_examples 'a period-based exception' do |exemption_type, exception_id, disabled_behavior|
    let(:member_data) do
      build(:certification_member_data, cert_date:, exemptions: [ exemption(exemption_type, **exemption_overrides) ])
    end
    let(:exemption_overrides) { { periods: } }

    context 'when the exemption period covers a month that can be certified' do
      let(:periods) { [ in_window_period ] }

      it_behaves_like 'an applied external exception', "#{exception_id}_excepted"
      it_behaves_like disabled_behavior, exception_id
    end

    context 'when the exemption period covers no month that can be certified' do
      let(:periods) { [ out_of_window_period ] }

      it_behaves_like 'a failed check'
    end

    context 'when one of several periods covers a month that can be certified' do
      let(:periods) { [ out_of_window_period, in_window_period ] }

      it_behaves_like 'an applied external exception', "#{exception_id}_excepted"
    end

    context 'when the exemption is unverified' do
      let(:exemption_overrides) { { periods: [ in_window_period ], verification_status: 'pending' } }

      it_behaves_like 'a failed check'
    end

    context 'when the exemption does not apply to the member' do
      let(:exemption_overrides) { { periods: [ in_window_period ], value: false } }

      it_behaves_like 'a failed check'
    end

    context 'when the period is open-ended' do
      let(:periods) { [ { period_start: cert_date - 2.months } ] }

      it_behaves_like 'a failed check'
    end

    context 'with invalid data' do
      let(:periods) { [ { period_start: 'not a date', period_end: 'not a date' } ] }

      it_behaves_like 'a failed check'
    end

    context 'when the member data carries no exemptions' do
      let(:member_data) { build(:certification_member_data, cert_date:) }

      it_behaves_like 'a failed check'
    end
  end

  describe '#determine' do
    let(:cert_date) { Date.new(2025, 7, 1) }
    let(:member_data) { build(:certification_member_data, cert_date:) }
    let(:months_that_can_be_certified) { (0..3).map { |i| cert_date - i.month } }
    # The certifiable window spans the four months ending with cert_date's month, so a period
    # inside cert_date - 2.months lands in it and one ending five months back lands outside it.
    let(:in_window_period) { { period_start: cert_date - 2.months, period_end: cert_date - 2.months } }
    let(:out_of_window_period) { { period_start: cert_date - 6.months, period_end: cert_date - 5.months } }
    let(:certification) do
      create(
        :certification,
        member_data:,
        certification_requirements: build(:certification_certification_requirements, certification_date: cert_date, months_that_can_be_certified:)
      )
    end

    context 'when no exception check applies (member data carries no exception signals)' do
      it_behaves_like 'a failed check'

      it 'logs a denied event in the audit log' do
        expect do
          service.determine(kase)
        end.to change {
          Strata::AuditLine.where(
            subject: certification,
            actor_type: described_class.name,
            action: 'case.exception.denied'
          ).count
        }.by(1)
      end

      it 'does not record an exception determination' do
        allow(kase).to receive(:record_exception_determination)
        service.determine(kase)
        expect(kase).not_to have_received(:record_exception_determination)
      end
    end

    context 'when applicant was under 19 years old' do
      let(:date_of_birth) { cert_date - (19.years + 2.months + 5.days) }
      let(:member_data) { build(:certification_member_data, cert_date:, date_of_birth:) }

      it_behaves_like 'an applied external exception', 'age_under_19_excepted'
      it_behaves_like 'a disabled mandatory exception', :age_under_19

      context 'when the applicant turned 19 before every month that can be certified' do
        let(:date_of_birth) { cert_date - 20.years }

        it_behaves_like 'a failed check'
      end
    end

    describe 'checking pregnancy' do
      context 'when a pregnancy period covers a month that can be certified' do
        let(:member_data) do
          build(:certification_member_data, cert_date:, exemptions: [ exemption(:pregnancy, periods: [ in_window_period ]) ])
        end

        it_behaves_like 'an applied external exception', 'pregnancy_excepted'
      end

      context 'when a postpartum period covers a month that can be certified' do
        let(:member_data) do
          build(:certification_member_data, cert_date:, exemptions: [ exemption(:postpartum, periods: [ in_window_period ]) ])
        end

        it_behaves_like 'an applied external exception', 'pregnancy_excepted'
      end

      context 'when the pregnancy covers a month that can be certified but postpartum does not' do
        let(:member_data) do
          build(
            :certification_member_data,
            cert_date:,
            exemptions: [
              exemption(:pregnancy, periods: [ in_window_period ]),
              exemption(:postpartum, periods: [ out_of_window_period ])
            ]
          )
        end

        it_behaves_like 'an applied external exception', 'pregnancy_excepted'
      end

      context 'when the pregnancy ended before every month that can be certified but postpartum has not' do
        let(:member_data) do
          build(
            :certification_member_data,
            cert_date:,
            exemptions: [
              exemption(:pregnancy, periods: [ out_of_window_period ]),
              exemption(:postpartum, periods: [ in_window_period ])
            ]
          )
        end

        it_behaves_like 'an applied external exception', 'pregnancy_excepted'
      end

      context 'when neither period covers a month that can be certified' do
        let(:member_data) do
          build(
            :certification_member_data,
            cert_date:,
            exemptions: [
              exemption(:pregnancy, periods: [ out_of_window_period ]),
              exemption(:postpartum, periods: [ out_of_window_period ])
            ]
          )
        end

        it_behaves_like 'a failed check'
      end
    end

    describe 'checking former foster care' do
      let(:member_data) do
        build(:certification_member_data, cert_date:, date_of_birth:, exemptions:)
      end
      let(:exemptions) { [ exemption(:former_foster_care) ] }

      context 'when a former foster youth is under the age cap during a certifiable month' do
        let(:date_of_birth) { cert_date - (25.years + 2.months) } # ~25 -> under 26

        it_behaves_like 'an applied external exception', 'former_foster_care_excepted'
      end

      context 'when a former foster youth is at/over the age cap in every certifiable month' do
        let(:date_of_birth) { cert_date - 27.years } # 27 -> over 26 throughout

        it_behaves_like 'a failed check'
      end

      context 'when a former foster youth turns 26 mid-way through the earliest certifiable month' do
        # 26th birthday is the 16th of the earliest certifiable month; still under 26 at its start
        let(:date_of_birth) { cert_date - 26.years - 3.months + 15.days }

        it_behaves_like 'an applied external exception', 'former_foster_care_excepted'
      end

      context 'when a former foster youth turns 26 on the first of the earliest certifiable month' do
        # 26th birthday is the 1st of the earliest certifiable month; already 26 at its start
        let(:date_of_birth) { cert_date - 26.years - 3.months }

        it_behaves_like 'a failed check'
      end

      context 'when the member has no former-foster-care exemption' do
        let(:date_of_birth) { cert_date - (25.years + 2.months) }
        let(:exemptions) { [] }

        it_behaves_like 'a failed check'
      end

      context 'when the exemption is unverified' do
        let(:date_of_birth) { cert_date - (25.years + 2.months) }
        let(:exemptions) { [ exemption(:former_foster_care, verification_status: 'pending') ] }

        it_behaves_like 'a failed check'
      end

      context 'when there is no date of birth' do
        let(:date_of_birth) { nil }

        it_behaves_like 'a failed check'
      end
    end

    describe 'checking caretaker' do
      let(:member_data) { build(:certification_member_data, cert_date:, exemptions:) }

      context 'when caring for a disabled person during a certifiable month' do
        let(:exemptions) { [ exemption(:caregiver_disability, periods: [ in_window_period ]) ] }

        it_behaves_like 'an applied external exception', 'caretaker_excepted'
      end

      context 'when caring for a disabled person only outside the certifiable months' do
        let(:exemptions) { [ exemption(:caregiver_disability, periods: [ out_of_window_period ]) ] }

        it_behaves_like 'a failed check'
      end

      # A caregiver_child period starts on the child's date of birth (as in the exclusion ruleset).
      context 'when caring for a dependent child under the age threshold' do
        let(:exemptions) { [ exemption(:caregiver_child, periods: [ { period_start: cert_date - 10.years } ]) ] } # age 10 < 14

        it_behaves_like 'an applied external exception', 'caretaker_excepted'
      end

      context 'when caring for both an under-threshold and an over-threshold child' do
        let(:exemptions) do
          [
            exemption(
              :caregiver_child,
              periods: [ { period_start: cert_date - 15.years }, { period_start: cert_date - 10.years } ]
            )
          ]
        end

        it_behaves_like 'an applied external exception', 'caretaker_excepted'
      end

      context 'when the dependent child is at/over the age threshold throughout' do
        let(:exemptions) { [ exemption(:caregiver_child, periods: [ { period_start: cert_date - 15.years } ]) ] }

        it_behaves_like 'a failed check'
      end

      context 'when the dependent child turns 14 mid-way through the earliest certifiable month' do
        let(:exemptions) do
          [ exemption(:caregiver_child, periods: [ { period_start: cert_date - 14.years - 3.months + 15.days } ]) ]
        end

        it_behaves_like 'an applied external exception', 'caretaker_excepted'
      end

      context 'when the dependent child turned 14 during the latest certifiable month' do
        # 14th birthday falls inside cert_date's month, so the child was under 14 in the months before it
        let(:exemptions) do
          [ exemption(:caregiver_child, periods: [ { period_start: cert_date - 14.years + 15.days } ]) ]
        end

        it_behaves_like 'an applied external exception', 'caretaker_excepted'
      end

      context 'when the dependent child was born part-way through the certifiable window' do
        let(:exemptions) { [ exemption(:caregiver_child, periods: [ { period_start: cert_date - 2.months } ]) ] }

        it_behaves_like 'an applied external exception', 'caretaker_excepted'
      end

      context 'when the dependent child was born after every month that can be certified' do
        let(:exemptions) { [ exemption(:caregiver_child, periods: [ { period_start: cert_date + 3.months } ]) ] }

        it_behaves_like 'a failed check'
      end

      context 'when the dependent child has no date of birth' do
        let(:exemptions) { [ exemption(:caregiver_child, periods: [ { period_end: cert_date } ]) ] }

        it_behaves_like 'a failed check'
      end

      context 'when there is no caretaking exemption' do
        let(:exemptions) { [] }

        it_behaves_like 'a failed check'
      end
    end

    describe 'checking veteran disability' do
      it_behaves_like 'a period-based exception', :veteran_disability, :veteran_disability, 'a disabled mandatory exception'
    end

    describe 'checking medically frail' do
      it_behaves_like 'a period-based exception', :medical_condition, :medically_frail, 'a disabled mandatory exception'
    end

    describe 'checking SNAP/TANF work' do
      it_behaves_like 'a period-based exception', :meeting_tanf_or_snap_work, :tanf_snap_work, 'a disabled mandatory exception'
    end

    describe 'checking drug treatment' do
      it_behaves_like 'a period-based exception', :substance_treatment, :drug_treatment, 'a disabled mandatory exception'
    end

    describe 'checking inmate' do
      # The shared out-of-window period would reach a certifiable month once the 3-month buffer is
      # added, so this check needs one that clears the window with the buffer included.
      let(:out_of_window_period) { { period_start: cert_date - 10.months, period_end: cert_date - 9.months } }

      it_behaves_like 'a period-based exception', :incarceration, :inmate, 'a disabled mandatory exception'

      context 'when the incarceration ended before the window but the buffer reaches into it' do
        # released cert_date - 5.months, so the 3-month buffer still covers a certifiable month
        let(:member_data) do
          build(
            :certification_member_data,
            cert_date:,
            exemptions: [
              exemption(:incarceration, periods: [ { period_start: cert_date - 6.months, period_end: cert_date - 5.months } ])
            ]
          )
        end

        it_behaves_like 'an applied external exception', 'inmate_excepted'
      end

      context 'when the incarceration window (incl. buffer) ended before every certifiable month' do
        let(:member_data) do
          build(
            :certification_member_data,
            cert_date:,
            exemptions: [
              exemption(:incarceration, periods: [ { period_start: cert_date - 10.months, period_end: cert_date - 9.months } ])
            ]
          )
        end

        it_behaves_like 'a failed check'
      end
    end

    describe 'checking participating-in-other-program' do
      it_behaves_like 'a period-based exception', :other_program, :other_program, 'a disabled mandatory exception'
    end

    describe 'checking inpatient-medical-care' do
      it_behaves_like 'a period-based exception', :inpatient_medical_care, :inpatient_medical_care, 'a disabled optional exception'
    end

    describe 'checking declared-emergency-county' do
      it_behaves_like 'a period-based exception', :declared_emergency_county, :declared_emergency_county, 'a disabled optional exception'
    end

    describe 'checking high-unemployment-county' do
      it_behaves_like 'a period-based exception', :high_unemployment_county, :high_unemployment_county, 'a disabled optional exception'
    end

    describe 'checking medical-travel' do
      it_behaves_like 'a period-based exception', :travel_for_medical, :medical_travel, 'a disabled optional exception'
    end

    context 'when more than one exception check would apply' do
      let(:member_data) do
        build(
          :certification_member_data,
          cert_date:,
          exemptions: [
            exemption(:travel_for_medical, periods: [ in_window_period ]),
            exemption(:inpatient_medical_care, periods: [ in_window_period ])
          ]
        )
      end

      it 'records only the first applicable reason (stops at first success)' do
        service.determine(kase)
        determination = Determination.where(subject: certification, outcome: 'excepted').first
        expect(determination.reasons).to eq([ 'inpatient_medical_care_excepted' ])
      end
    end

    # Isolates the determine() plumbing from the concrete checks: whatever reason codes the checks
    # produce, determine records them and publishes DeterminedExcepted.
    context 'when checks are stubbed (positive-path wiring)' do
      before do
        allow(service).to receive(:applicable_exception_reason_codes).and_return([ 'inpatient_medical_care_excepted' ])
        allow(kase).to receive(:record_exception_determination)
      end

      it 'records the exception determination on the case' do
        service.determine(kase)
        expect(kase).to have_received(:record_exception_determination).with([ 'inpatient_medical_care_excepted' ], service)
      end

      it 'publishes DeterminedExcepted' do
        service.determine(kase)
        expect(Strata::EventManager).to have_received(:publish)
          .with('DeterminedExcepted', { case_id: kase.id, certification_id: kase.certification_id })
      end
    end
  end
end
