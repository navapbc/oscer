# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rules::ExclusionRuleset do
  let(:ruleset) { described_class.new }
  let(:cert_date) { Date.new(2025, 7, 20) }

  describe '#is_pregnant' do
    context 'when the pregnancy and postpartum both nil' do
      it 'returns nil' do
        expect(ruleset.is_pregnant(nil, nil, cert_date)).to be_nil
      end
    end

    context 'when the certification date is nil' do
      it 'returns nil' do
        pregnancy = build(:certification_member_data_exemption, :period_end_valid, cert_date:)
        postpartum = build(:certification_member_data_exemption, :period_end_valid, cert_date:)
        expect(ruleset.is_pregnant(pregnancy, postpartum, nil)).to be_falsey
      end
    end

    context 'when the due date is in the future (member is currently expecting)' do
      it 'returns true' do
        pregnancy = build(:certification_member_data_exemption, :period_end_valid, cert_date:)
        expect(ruleset.is_pregnant(pregnancy, nil, cert_date)).to be true
      end
    end

    context 'when the parturition date ends in future' do
      it 'returns true' do
        postpartum = build(:certification_member_data_exemption, :period_end_valid, cert_date:)
        expect(ruleset.is_pregnant(nil, postpartum, cert_date)).to be true
      end
    end

    context 'when the pregnancy ends before certification date' do
      it 'returns false' do
        pregnancy = build(:certification_member_data_exemption, :period_end_invalid, cert_date:)
        expect(ruleset.is_pregnant(pregnancy, nil, cert_date)).to be_falsey
      end
    end

    context 'when the parturition date ends before certification date' do
      it 'returns false' do
        postpartum = build(:certification_member_data_exemption, :period_end_invalid, cert_date:)
        expect(ruleset.is_pregnant(nil, postpartum, cert_date)).to be_falsey
      end
    end

    context 'when the pregnancy in past and partirution in future' do
      it 'returns false' do
        pregnancy = build(:certification_member_data_exemption, :period_end_invalid, cert_date:)
        postpartum = build(:certification_member_data_exemption, :period_end_valid, cert_date:)
        expect(ruleset.is_pregnant(pregnancy, postpartum, cert_date)).to be true
      end
    end
  end

  describe '#is_american_indian_or_alaska_native' do
    context 'when param is nil' do
      it 'returns nil' do
        expect(ruleset.is_american_indian_or_alaska_native(nil)).to be_falsey
      end
    end

    context 'when param is not nil' do
      it 'returns param' do
        expect(ruleset.is_american_indian_or_alaska_native('anything')).to be_truthy
      end
    end
  end

  describe '#is_veteran_with_disability' do
    context 'when the veteran-with-disability flag is unknown (nil)' do
      it 'returns falsey' do
        expect(ruleset.is_veteran_with_disability(nil, cert_date)).to be_falsey
      end
    end

    context 'when the member is no longer a veteran with a disability' do
      it 'returns falsey' do
        veteran_with_disability = build(:certification_member_data_exemption, :period_end_invalid, cert_date:)
        expect(ruleset.is_veteran_with_disability(veteran_with_disability, cert_date)).to be_falsey
      end
    end

    context 'when the member is a veteran with a disability' do
      it 'returns true' do
        veteran_with_disability = build(:certification_member_data_exemption, :period_end_valid, cert_date:)
        expect(ruleset.is_veteran_with_disability(veteran_with_disability, cert_date)).to be_truthy
      end
    end
  end

  describe '#former_foster_care' do
    # Former foster youth are excluded until age 26, evaluated against the certification date at
    # month granularity (consistent with pregnancy).
    let(:was_in_foster_care) { 'some exemption object' }

    context 'when the member was not in foster care' do
      it 'returns falsey' do
        expect(ruleset.former_foster_care(nil, cert_date - 20.years, cert_date)).to be_falsey
      end
    end

    context 'when the date of birth is nil' do
      it 'returns falsey' do
        expect(ruleset.former_foster_care(was_in_foster_care, nil, cert_date)).to be_falsey
      end
    end

    context 'when the certification date is nil' do
      it 'returns falsey' do
        expect(ruleset.former_foster_care(was_in_foster_care, cert_date - 20.years, nil)).to be_falsey
      end
    end

    context 'when the member was in foster care and is under 26' do
      it 'returns true' do
        expect(ruleset.former_foster_care(was_in_foster_care, cert_date - 20.years, cert_date)).to be true
      end
    end

    context 'when the member turns 26 during the certification month (month granularity)' do
      it 'returns true' do
        date_of_birth = Date.new(1999, 7, 25) # 26th birthday 2025-07-25, later in the cert month
        expect(ruleset.former_foster_care(was_in_foster_care, date_of_birth, cert_date)).to be true
      end
    end

    context 'when the member reached 26 before the certification month' do
      it 'returns falsey' do
        date_of_birth = Date.new(1999, 6, 25) # 26th birthday 2025-06-25, the month before
        expect(ruleset.former_foster_care(was_in_foster_care, date_of_birth, cert_date)).to be_falsey
      end
    end

    context 'when the member was in foster care but is 26 or older' do
      it 'returns falsey' do
        expect(ruleset.former_foster_care(was_in_foster_care, cert_date - 30.years, cert_date)).to be_falsey
      end
    end
  end

  describe '#medically_frail' do
    context 'when the currently-medically-frail flag is unknown (nil)' do
      it 'returns falsey' do
        expect(ruleset.medically_frail(nil, cert_date)).to be_falsey
      end
    end

    context 'when the member is not currently medically frail' do
      it 'returns falsey' do
        medical_condition = build(:certification_member_data_exemption, :period_end_invalid, cert_date:)
        expect(ruleset.medically_frail(medical_condition, cert_date)).to be_falsey
      end
    end

    context 'when the member became medically frail after certification date' do
      it 'returns falsey' do
        medicall_condition = build(:certification_member_data_exemption, :valid, cert_date:)
        period = Certifications::MemberData::Period.new(period_start: cert_date + 1.month, period_end: cert_date + 2.months)
        medicall_condition.periods = [ period ]
        expect(ruleset.inmate(medicall_condition, cert_date)).to be_falsey
      end
    end

    context 'when the member is currently medically frail' do
      it 'returns true' do
        medical_condition = build(:certification_member_data_exemption, :period_end_valid, cert_date:)
        expect(ruleset.medically_frail(medical_condition, cert_date)).to be_truthy
      end
    end
  end

  describe '#caretaker' do
    # Excluded when caretaking an infirm person during the certification month, or caring for a
    # dependent child 13 or under (both evaluated against the certification date at month
    # granularity, consistent with the other date-based checks).

    context 'when no caretaker signals are present' do
      it 'returns falsey' do
        expect(ruleset.caretaker(nil, nil, cert_date)).to be_falsey
      end
    end

    context 'when the certification date is nil' do
      it 'returns falsey' do
        expect(ruleset.caretaker([ cert_date ], [ cert_date - 5.years ], nil)).to be_falsey
      end
    end

    context 'when caretaking an infirm person during the certification month' do
      it 'returns true' do
        infirm = build(:certification_member_data_exemption, :period_end_valid, cert_date:)
        expect(ruleset.caretaker(infirm, nil, cert_date)).to be true
      end
    end

    context 'when caretaking an infirm person only outside the certification month' do
      it 'returns falsey' do
        infirm = build(:certification_member_data_exemption, :period_end_invalid, cert_date:)
        expect(ruleset.caretaker(infirm, nil, cert_date)).to be_falsey
      end
    end

    context 'when the member has a dependent child under 14' do
      it 'returns true' do
        dependent = build(:certification_member_data_exemption, :valid, cert_date:)
        period = Certifications::MemberData::Period.new(period_start: cert_date - 5.years)
        dependent.periods = [ period ]
        expect(ruleset.caretaker(nil, dependent, cert_date)).to be true
      end
    end

    context 'when a dependent child turns 14 during the certification month (month granularity)' do
      it 'returns true' do
        dependent = build(:certification_member_data_exemption, :valid, cert_date:)
        period = Certifications::MemberData::Period.new(period_start: cert_date - 14.years + 1.day)
        dependent.periods = [ period ]
        expect(ruleset.caretaker(nil, dependent, cert_date)).to be true
      end
    end

    context 'when a dependent child reached 14 before the certification month' do
      it 'returns falsey' do
        dependent = build(:certification_member_data_exemption, :valid, cert_date:)
        period = Certifications::MemberData::Period.new(period_start: cert_date - 14.years - 1.month)
        dependent.periods = [ period ]
        expect(ruleset.caretaker(nil, dependent, cert_date)).to be_falsey
      end
    end

    context 'when all dependent children are 14 or older' do
      it 'returns falsey' do
        dependent = build(:certification_member_data_exemption, :valid, cert_date:)
        period_a = Certifications::MemberData::Period.new(period_start: cert_date - 15.years)
        period_b = Certifications::MemberData::Period.new(period_start: cert_date - 20.years)
        dependent.periods = [ period_a, period_b ]
        expect(ruleset.caretaker(nil, dependent, cert_date)).to be_falsey
      end
    end

    context 'when one of several dependent children is under 14' do
      it 'returns true' do
        dependent = build(:certification_member_data_exemption, :valid, cert_date:)
        period_a = Certifications::MemberData::Period.new(period_start: cert_date - 5.years)
        period_b = Certifications::MemberData::Period.new(period_start: cert_date - 20.years)
        dependent.periods = [ period_a, period_b ]
        expect(ruleset.caretaker(nil, dependent, cert_date)).to be_truthy
      end
    end
  end

  describe '#tanf_snap_work' do
    context 'when the meeting-SNAP/TANF-work flag is unknown (nil)' do
      it 'returns falsey' do
        expect(ruleset.tanf_snap_work(nil, cert_date)).to be_falsey
      end
    end

    context 'when certification date is nil' do
      it 'returns falsey' do
        tanf = build(:certification_member_data_exemption, :period_end_valid, cert_date:)
        expect(ruleset.tanf_snap_work(tanf, nil)).to be_falsey
      end
    end

    context 'when the member is not meeting SNAP/TANF work requirements' do
      it 'returns falsey' do
        tanf = build(:certification_member_data_exemption, :period_end_invalid, cert_date:)
        expect(ruleset.tanf_snap_work(tanf, cert_date)).to be_falsey
      end
    end

    context 'when the member is meeting SNAP/TANF work requirements' do
      it 'returns true' do
        tanf = build(:certification_member_data_exemption, :period_end_valid, cert_date:)
        expect(ruleset.tanf_snap_work(tanf, cert_date)).to be true
      end
    end
  end

  describe '#drug_treatment' do
    # Excluded when in drug/alcohol treatment during the certification month (month granularity).

    context 'when no treatment dates are present' do
      it 'returns falsey' do
        expect(ruleset.drug_treatment(nil, cert_date)).to be_falsey
      end
    end

    context 'when the certification date is nil' do
      it 'returns falsey' do
        expect(ruleset.drug_treatment([ cert_date ], nil)).to be_falsey
      end
    end

    context 'when in treatment during the certification month' do
      it 'returns true' do
        drug_treatment = build(:certification_member_data_exemption, :period_end_valid, cert_date:)
        expect(ruleset.drug_treatment(drug_treatment, cert_date)).to be true
      end
    end

    context 'when in treatment only outside the certification month' do
      it 'returns falsey' do
        drug_treatment = build(:certification_member_data_exemption, :period_end_invalid, cert_date:)
        expect(ruleset.drug_treatment(drug_treatment, cert_date)).to be false
      end
    end
  end

  describe '#inmate' do
    # Excluded while incarcerated and for a 3-month buffer afterward (INMATE_BUFFER_MONTHS),
    # evaluated against the certification date at month granularity.

    context 'when no incarceration dates are present' do
      it 'returns falsey' do
        expect(ruleset.inmate(nil, cert_date)).to be_falsey
      end
    end

    context 'when no incarceration periods are present' do
      it 'returns falsey' do
        incarceration = build(:certification_member_data_exemption, :valid, cert_date:)
        expect(ruleset.inmate(incarceration, cert_date)).to be_falsey
      end
    end

    context 'when no incarceration end dates are present' do
      it 'returns falsey' do
        incarceration = build(:certification_member_data_exemption, :valid, cert_date:)
        period = Certifications::MemberData::Period.new(period_start: cert_date - 3.months)
        expect(ruleset.inmate(incarceration, cert_date)).to be_falsey
      end
    end

    context 'when the certification date is nil' do
      it 'returns falsey' do
        incarceration = build(:certification_member_data_exemption, :period_end_valid, cert_date:)
        expect(ruleset.inmate(incarceration, nil)).to be_falsey
      end
    end

    context 'when incarcerated during the certification month' do
      it 'returns true' do
        incarceration = build(:certification_member_data_exemption, :period_end_valid, cert_date:)
        expect(ruleset.inmate(incarceration, cert_date)).to be true
      end
    end

    context 'when incarcerated within the 3-month buffer before the certification month' do
      it 'returns true' do
        incarceration = build(:certification_member_data_exemption, :valid, cert_date:)
        period = Certifications::MemberData::Period.new(period_start: cert_date - 1.year, period_end: cert_date - 3.months)
        incarceration.periods = [ period ]
        expect(ruleset.inmate(incarceration, cert_date)).to be true
      end
    end

    context 'when incarceration ended more than 3 months before the certification month' do
      it 'returns falsey' do
        incarceration = build(:certification_member_data_exemption, :valid, cert_date:)
        period = Certifications::MemberData::Period.new(period_start: cert_date - 1.year, period_end: cert_date - 4.months)
        incarceration.periods = [ period ]
        expect(ruleset.inmate(incarceration, cert_date)).to be_falsey
      end
    end

    context 'when incarceration began after the certification month' do
      it 'returns falsey' do
        incarceration = build(:certification_member_data_exemption, :valid, cert_date:)
        period = Certifications::MemberData::Period.new(period_start: cert_date + 1.month, period_end: cert_date + 2.months)
        incarceration.periods = [ period ]
        expect(ruleset.inmate(incarceration, cert_date)).to be_falsey
      end
    end

    context 'when more than one and one is within the 3-month buffer before the certification month' do
      it 'returns true' do
        incarceration = build(:certification_member_data_exemption, :valid, cert_date:)
        period_a = Certifications::MemberData::Period.new(period_start: cert_date - 1.year, period_end: cert_date - 4.months)
        period_b = Certifications::MemberData::Period.new(period_start: cert_date - 1.year, period_end: cert_date - 3.months)
        incarceration.periods = [ period_a, period_b ]
        expect(ruleset.inmate(incarceration, cert_date)).to be true
      end
    end
  end

  describe '#eligible_for_exclusion' do
    context 'when all parameters are nil' do
      it 'returns falsey' do
        expect(ruleset.eligible_for_exclusion(nil, nil, nil, nil, nil, nil, nil, nil, nil)).to be_falsey
      end
    end

    context 'when only is_pregnant is true' do
      it 'returns true' do
        expect(ruleset.eligible_for_exclusion(true, nil, nil, nil, nil, nil, nil, nil, nil)).to be true
      end
    end

    context 'when only is_american_indian_or_alaska_native is true' do
      it 'returns true' do
        expect(ruleset.eligible_for_exclusion(nil, true, nil, nil, nil, nil, nil, nil, nil)).to be true
      end
    end

    context 'when only is_veteran_with_disability is true' do
      it 'returns true' do
        expect(ruleset.eligible_for_exclusion(nil, nil, true, nil, nil, nil, nil, nil, nil)).to be true
      end
    end

    context 'when only former_foster_care is true' do
      it 'returns true' do
        expect(ruleset.eligible_for_exclusion(nil, nil, nil, true, nil, nil, nil, nil, nil)).to be true
      end
    end

    context 'when only medically_frail is true' do
      it 'returns true' do
        expect(ruleset.eligible_for_exclusion(nil, nil, nil, nil, true, nil, nil, nil, nil)).to be true
      end
    end

    context 'when only caretaker is true' do
      it 'returns true' do
        expect(ruleset.eligible_for_exclusion(nil, nil, nil, nil, nil, true, nil, nil, nil)).to be true
      end
    end

    context 'when only tanf_snap_work is true' do
      it 'returns true' do
        expect(ruleset.eligible_for_exclusion(nil, nil, nil, nil, nil, nil, true, nil, nil)).to be true
      end
    end

    context 'when only drug_treatment is true' do
      it 'returns true' do
        expect(ruleset.eligible_for_exclusion(nil, nil, nil, nil, nil, nil, nil, true, nil)).to be true
      end
    end

    context 'when only inmate is true' do
      it 'returns true' do
        expect(ruleset.eligible_for_exclusion(nil, nil, nil, nil, nil, nil, nil, nil, true)).to be true
      end
    end

    context 'when multiple parameters are true' do
      it 'returns true' do
        expect(ruleset.eligible_for_exclusion(true, true, nil, nil, nil, nil, nil, nil, nil)).to be true
      end
    end

    context 'when all are true' do
      it 'returns true' do
        expect(ruleset.eligible_for_exclusion(true, true, true, true, true, true, true, true, true)).to be true
      end
    end

    context 'when all are false' do
      it 'returns falsey' do
        expect(ruleset.eligible_for_exclusion(false, false, false, false, false, false, false, false, false)).to be_falsey
      end
    end

    context 'when some are false but one is true' do
      it 'returns true' do
        expect(ruleset.eligible_for_exclusion(false, true, false, false, false, false, false, false, false)).to be true
      end
    end
  end
end
