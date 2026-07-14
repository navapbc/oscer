# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rules::ExclusionRuleset do
  let(:ruleset) { described_class.new }

  describe '#is_pregnant' do
    let(:certification_date) { Date.new(2025, 7, 1) }

    context 'when the due/parturition date is nil' do
      it 'returns nil' do
        expect(ruleset.is_pregnant(nil, certification_date)).to be_nil
      end
    end

    context 'when the certification date is nil' do
      it 'returns nil' do
        expect(ruleset.is_pregnant(Date.new(2025, 6, 1), nil)).to be_nil
      end
    end

    context 'when the due date is in the future (member is currently expecting)' do
      it 'returns true' do
        expect(ruleset.is_pregnant(certification_date + 3.months, certification_date)).to be true
      end
    end

    context 'when the parturition date is within the prior 12 months' do
      it 'returns true' do
        expect(ruleset.is_pregnant(certification_date - 6.months, certification_date)).to be true
      end
    end

    context 'when the certification date is exactly 12 months after the parturition date (boundary)' do
      it 'returns true' do
        expect(ruleset.is_pregnant(certification_date - 12.months, certification_date)).to be true
      end
    end

    context 'when the window ends the same month as the certification date but on an earlier day' do
      it 'returns true' do
        certification_date = Date.new(2025, 7, 20)
        parturition_date = Date.new(2024, 7, 5)
        expect(ruleset.is_pregnant(parturition_date, certification_date)).to be true
      end
    end

    context 'when the window ends the month before the certification date' do
      it 'returns false' do
        certification_date = Date.new(2025, 7, 20)
        parturition_date = Date.new(2024, 6, 25)
        expect(ruleset.is_pregnant(parturition_date, certification_date)).to be false
      end
    end

    context 'when the parturition date is more than 12 months before the certification date' do
      it 'returns false' do
        expect(ruleset.is_pregnant(certification_date - 13.months, certification_date)).to be false
      end
    end
  end

  describe '#is_american_indian_or_alaska_native' do
    context 'when race_ethnicity is nil' do
      it 'returns nil' do
        expect(ruleset.is_american_indian_or_alaska_native(nil)).to be_nil
      end
    end

    [
      "american_indian_or_alaska_native",
      "american_indian",
      "alaska_native",
      "AmErIcAn_InDiAn",
      "ALASKA_NATIVE",
      "american indian",
      "alaska native"
    ].each do |race_ethnicity_value|
      context "when race_ethnicity is #{race_ethnicity_value.inspect}" do
        it 'returns true' do
          expect(ruleset.is_american_indian_or_alaska_native(race_ethnicity_value)).to be true
        end
      end
    end

    context 'when race_ethnicity is another category' do
      it 'returns false' do
        expect(ruleset.is_american_indian_or_alaska_native("white")).to be false
        expect(ruleset.is_american_indian_or_alaska_native("black_or_african_american")).to be false
        expect(ruleset.is_american_indian_or_alaska_native("asian")).to be false
        expect(ruleset.is_american_indian_or_alaska_native("native_hawaiian_or_other_pacific_islander")).to be false
      end
    end
  end

  describe '#is_veteran_with_disability' do
    context 'when the veteran-with-disability flag is unknown (nil)' do
      it 'returns falsey' do
        expect(ruleset.is_veteran_with_disability(nil)).to be_falsey
      end
    end

    context 'when the member is not a veteran with a disability' do
      it 'returns falsey' do
        expect(ruleset.is_veteran_with_disability(false)).to be_falsey
      end
    end

    context 'when the member is a veteran with a disability' do
      it 'returns true' do
        expect(ruleset.is_veteran_with_disability(true)).to be true
      end
    end
  end

  describe '#former_foster_care' do
    # Former foster youth are excluded until age 26, evaluated against the certification date at
    # month granularity (consistent with pregnancy).
    let(:certification_date) { Date.new(2025, 7, 1) }

    context 'when the member was not in foster care' do
      it 'returns falsey' do
        expect(ruleset.former_foster_care(false, certification_date - 20.years, certification_date)).to be_falsey
      end
    end

    context 'when foster-care history is unknown (nil)' do
      it 'returns falsey' do
        expect(ruleset.former_foster_care(nil, certification_date - 20.years, certification_date)).to be_falsey
      end
    end

    context 'when the date of birth is nil' do
      it 'returns falsey' do
        expect(ruleset.former_foster_care(true, nil, certification_date)).to be_falsey
      end
    end

    context 'when the certification date is nil' do
      it 'returns falsey' do
        expect(ruleset.former_foster_care(true, certification_date - 20.years, nil)).to be_falsey
      end
    end

    context 'when the member was in foster care and is under 26' do
      it 'returns true' do
        expect(ruleset.former_foster_care(true, certification_date - 20.years, certification_date)).to be true
      end
    end

    context 'when the member turns 26 during the certification month (month granularity)' do
      it 'returns true' do
        certification_date = Date.new(2025, 7, 20)
        date_of_birth = Date.new(1999, 7, 25) # 26th birthday 2025-07-25, later in the cert month
        expect(ruleset.former_foster_care(true, date_of_birth, certification_date)).to be true
      end
    end

    context 'when the member reached 26 before the certification month' do
      it 'returns falsey' do
        certification_date = Date.new(2025, 7, 20)
        date_of_birth = Date.new(1999, 6, 25) # 26th birthday 2025-06-25, the month before
        expect(ruleset.former_foster_care(true, date_of_birth, certification_date)).to be_falsey
      end
    end

    context 'when the member was in foster care but is 26 or older' do
      it 'returns falsey' do
        expect(ruleset.former_foster_care(true, certification_date - 30.years, certification_date)).to be_falsey
      end
    end
  end

  describe '#medically_frail' do
    context 'when the currently-medically-frail flag is unknown (nil)' do
      it 'returns falsey' do
        expect(ruleset.medically_frail(nil)).to be_falsey
      end
    end

    context 'when the member is not currently medically frail' do
      it 'returns falsey' do
        expect(ruleset.medically_frail(false)).to be_falsey
      end
    end

    context 'when the member is currently medically frail' do
      it 'returns true' do
        expect(ruleset.medically_frail(true)).to be true
      end
    end
  end

  describe '#caretaker' do
    # Excluded when caretaking an infirm person during the certification month, or caring for a
    # dependent child 13 or under (both evaluated against the certification date at month
    # granularity, consistent with the other date-based checks).
    let(:certification_date) { Date.new(2025, 7, 1) }

    context 'when no caretaker signals are present' do
      it 'returns falsey' do
        expect(ruleset.caretaker([], [], certification_date)).to be_falsey
        expect(ruleset.caretaker(nil, nil, certification_date)).to be_falsey
      end
    end

    context 'when the certification date is nil' do
      it 'returns falsey' do
        expect(ruleset.caretaker([ certification_date ], [ certification_date - 5.years ], nil)).to be_falsey
      end
    end

    context 'when caretaking an infirm person during the certification month' do
      it 'returns true' do
        expect(ruleset.caretaker([ certification_date + 15.days ], [], certification_date)).to be true
      end
    end

    context 'when caretaking an infirm person only outside the certification month' do
      it 'returns falsey' do
        expect(ruleset.caretaker([ certification_date - 1.month ], [], certification_date)).to be_falsey
      end
    end

    context 'when the member has a dependent child under 14' do
      it 'returns true' do
        expect(ruleset.caretaker([], [ certification_date - 5.years ], certification_date)).to be true
      end
    end

    context 'when a dependent child turns 14 during the certification month (month granularity)' do
      it 'returns true' do
        certification_date = Date.new(2025, 7, 20)
        child_birth_date = Date.new(2011, 7, 25) # 14th birthday 2025-07-25, later in the cert month
        expect(ruleset.caretaker([], [ child_birth_date ], certification_date)).to be true
      end
    end

    context 'when a dependent child reached 14 before the certification month' do
      it 'returns falsey' do
        certification_date = Date.new(2025, 7, 20)
        child_birth_date = Date.new(2011, 6, 25) # 14th birthday 2025-06-25, the month before
        expect(ruleset.caretaker([], [ child_birth_date ], certification_date)).to be_falsey
      end
    end

    context 'when all dependent children are 14 or older' do
      it 'returns falsey' do
        expect(ruleset.caretaker([], [ certification_date - 15.years, certification_date - 20.years ], certification_date)).to be_falsey
      end
    end

    context 'when one of several dependent children is under 14' do
      it 'returns true' do
        expect(ruleset.caretaker([], [ certification_date - 20.years, certification_date - 5.years ], certification_date)).to be true
      end
    end
  end

  describe '#tanf_snap_work' do
    context 'when the meeting-SNAP/TANF-work flag is unknown (nil)' do
      it 'returns falsey' do
        expect(ruleset.tanf_snap_work(nil)).to be_falsey
      end
    end

    context 'when the member is not meeting SNAP/TANF work requirements' do
      it 'returns falsey' do
        expect(ruleset.tanf_snap_work(false)).to be_falsey
      end
    end

    context 'when the member is meeting SNAP/TANF work requirements' do
      it 'returns true' do
        expect(ruleset.tanf_snap_work(true)).to be true
      end
    end
  end

  describe '#drug_treatment' do
    # Excluded when in drug/alcohol treatment during the certification month (month granularity).
    let(:certification_date) { Date.new(2025, 7, 1) }

    context 'when no treatment dates are present' do
      it 'returns falsey' do
        expect(ruleset.drug_treatment([], certification_date)).to be_falsey
        expect(ruleset.drug_treatment(nil, certification_date)).to be_falsey
      end
    end

    context 'when the certification date is nil' do
      it 'returns falsey' do
        expect(ruleset.drug_treatment([ certification_date ], nil)).to be_falsey
      end
    end

    context 'when in treatment during the certification month' do
      it 'returns true' do
        expect(ruleset.drug_treatment([ certification_date + 15.days ], certification_date)).to be true
      end
    end

    context 'when in treatment only outside the certification month' do
      it 'returns falsey' do
        expect(ruleset.drug_treatment([ certification_date - 1.month ], certification_date)).to be_falsey
      end
    end
  end

  describe '#inmate' do
    # Excluded while incarcerated and for a 3-month buffer afterward (INMATE_BUFFER_MONTHS),
    # evaluated against the certification date at month granularity.
    let(:certification_date) { Date.new(2025, 7, 1) }

    context 'when no incarceration dates are present' do
      it 'returns falsey' do
        expect(ruleset.inmate([], certification_date)).to be_falsey
        expect(ruleset.inmate(nil, certification_date)).to be_falsey
      end
    end

    context 'when the certification date is nil' do
      it 'returns falsey' do
        expect(ruleset.inmate([ certification_date ], nil)).to be_falsey
      end
    end

    context 'when incarcerated during the certification month' do
      it 'returns true' do
        expect(ruleset.inmate([ certification_date + 10.days ], certification_date)).to be true
      end
    end

    context 'when incarcerated within the 3-month buffer before the certification month' do
      it 'returns true' do
        expect(ruleset.inmate([ certification_date - 3.months ], certification_date)).to be true
      end
    end

    context 'when incarceration ended more than 3 months before the certification month' do
      it 'returns falsey' do
        expect(ruleset.inmate([ certification_date - 4.months ], certification_date)).to be_falsey
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
