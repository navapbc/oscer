# frozen_string_literal: true

require "rails_helper"

RSpec.describe Certifications::HouseholdData do
  describe Certifications::HouseholdData::GrossIncome do
    subject(:gross_income) do
      described_class.new(
        gross_income: amount,
        period_start: period_start,
        period_end: period_end
      )
    end

    let(:amount) { 250 }
    let(:period_start) { Date.new(2025, 11, 1) }
    let(:period_end) { Date.new(2025, 11, 30) }

    it "is valid with an amount and a period" do
      expect(gross_income).to be_valid
    end

    context "when the amount is missing" do
      let(:amount) { nil }

      it "is invalid" do
        expect(gross_income).not_to be_valid
        expect(gross_income.errors).to be_of_kind(:gross_income, :blank)
      end
    end

    context "when the amount is not greater than zero" do
      let(:amount) { 0 }

      it "is invalid" do
        expect(gross_income).not_to be_valid
        expect(gross_income.errors).to be_of_kind(:gross_income, :greater_than)
      end
    end

    context "when the period start is missing" do
      let(:period_start) { nil }

      it "is invalid" do
        expect(gross_income).not_to be_valid
        expect(gross_income.errors).to be_of_kind(:period_start, :blank)
      end
    end

    context "when the period end is missing" do
      let(:period_end) { nil }

      it "is invalid" do
        expect(gross_income).not_to be_valid
        expect(gross_income.errors).to be_of_kind(:period_end, :blank)
      end
    end
  end

  describe Certifications::HouseholdData::Member do
    describe "ssn" do
      it "normalizes a formatted tax ID to digits" do
        member = described_class.new(ssn: "000-00-0001")

        expect(member.ssn).to be_a(Strata::TaxId)
        expect(member.ssn).to eq("000000001")
      end

      it "casts a tax ID arriving as a JSON string" do
        member = described_class.new_filtered({ "ssn" => "000000001" }.with_indifferent_access)

        expect(member.ssn).to eq(Strata::TaxId.new("000000001"))
      end

      it "is valid without a tax ID" do
        expect(described_class.new(ssn: nil)).to be_valid
      end

      it "is invalid when the tax ID is not nine digits" do
        member = described_class.new(ssn: "not-a-tax-id")

        expect(member).not_to be_valid
        expect(member.errors).to be_of_kind(:ssn, :invalid)
      end
    end

    describe "#same_person_as?" do
      subject(:household_member) do
        described_class.new(
          ssn: household_ssn,
          name: { first: "Kitty", middle: "Gwendolyn", last: "Doe" },
          date_of_birth: household_date_of_birth
        )
      end

      let(:household_ssn) { "000000001" }
      let(:household_date_of_birth) { Date.new(1967, 1, 22) }

      let(:member_data) do
        Certifications::MemberData.new(
          ssn: member_ssn,
          name: { first: "Kitty", middle: "Gwendolyn", last: "Doe" },
          date_of_birth: Date.new(1967, 1, 22)
        )
      end
      let(:member_ssn) { "000000001" }

      it "is true when the tax IDs match" do
        expect(household_member.same_person_as?(member_data)).to be(true)
      end

      it "is true when the tax IDs match after normalization" do
        member = described_class.new(ssn: "000-00-0001")

        expect(member.same_person_as?(member_data)).to be(true)
      end

      it "is false when the tax IDs differ" do
        member = described_class.new(ssn: "000000002")

        expect(member.same_person_as?(member_data)).to be(false)
      end

      it "is false when there is no member data" do
        expect(household_member.same_person_as?(nil)).to be(false)
      end

      context "when the household member has no tax ID" do
        let(:household_ssn) { nil }

        it "is true when the name and date of birth match" do
          expect(household_member.same_person_as?(member_data)).to be(true)
        end

        it "ignores case and surrounding whitespace in the name" do
          member = described_class.new(
            name: { first: " kitty ", last: "DOE" },
            date_of_birth: household_date_of_birth
          )

          expect(member.same_person_as?(member_data)).to be(true)
        end

        it "is false when the name differs" do
          member = described_class.new(
            name: { first: "Richard", last: "Doe" },
            date_of_birth: household_date_of_birth
          )

          expect(member.same_person_as?(member_data)).to be(false)
        end

        it "is false when the date of birth differs" do
          member = described_class.new(
            name: { first: "Kitty", last: "Doe" },
            date_of_birth: Date.new(1983, 10, 2)
          )

          expect(member.same_person_as?(member_data)).to be(false)
        end

        it "is false when the date of birth is missing" do
          member = described_class.new(name: { first: "Kitty", last: "Doe" })

          expect(member.same_person_as?(member_data)).to be(false)
        end

        it "is false when the name is missing" do
          member = described_class.new(date_of_birth: household_date_of_birth)

          expect(member.same_person_as?(member_data)).to be(false)
        end
      end

      context "when the member data has no tax ID" do
        let(:member_ssn) { nil }

        it "is true when the name and date of birth match" do
          expect(household_member.same_person_as?(member_data)).to be(true)
        end
      end
    end
  end

  describe "validation" do
    subject(:household_data) do
      described_class.new(
        members: [
          {
            name: { first: "Elizabeth", last: "Doe" },
            ssn: "000000002",
            gross_incomes: [ { gross_income: nil, period_start: nil, period_end: nil } ]
          }
        ]
      )
    end

    it "surfaces errors from a household member's gross income" do
      expect(household_data).not_to be_valid
      expect(household_data.errors).to be_of_kind(:"members[0].gross_incomes[0].gross_income", :blank)
      expect(household_data.errors).to be_of_kind(:"members[0].gross_incomes[0].period_start", :blank)
    end
  end
end
