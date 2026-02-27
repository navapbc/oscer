# frozen_string_literal: true

require "rails_helper"

RSpec.describe DocAiResult::W2 do
  subject(:w2) { described_class.build(response) }

  let(:response) do
    {
      "job_id"               => "e8b21c94-5d4f-48a9-bc91-37d6f4a09c11",
      "status"               => "completed",
      "matchedDocumentClass" => "W2",
      "fields" => {
        "employerInfo.employerName"                    => { "confidence" => 0.92, "value" => "University of North Carolina" },
        "employerInfo.ein"                             => { "confidence" => 0.95, "value" => "56-6001393" },
        "employerInfo.employerAddress"                 => { "confidence" => 0.88, "value" => "123 College Ave" },
        "employerInfo.controlNumber"                   => { "confidence" => 0.80, "value" => "CTL001" },
        "employerInfo.employerZipCode"                 => { "confidence" => 0.90, "value" => "27599" },
        "filingInfo.ombNumber"                         => { "confidence" => 0.99, "value" => "1545-0008" },
        "filingInfo.verificationCode"                  => { "confidence" => 0.75, "value" => "VER001" },
        "employeeGeneralInfo.firstName"                => { "confidence" => 0.96, "value" => "Jane" },
        "employeeGeneralInfo.employeeLastName"         => { "confidence" => 0.96, "value" => "Smith" },
        "employeeGeneralInfo.employeeAddress"          => { "confidence" => 0.88, "value" => "456 Oak St" },
        "employeeGeneralInfo.employeeZipCode"          => { "confidence" => 0.90, "value" => "27514" },
        "employeeGeneralInfo.ssn"                      => { "confidence" => 0.97, "value" => "XXX-XX-1234" },
        "federalTaxInfo.federalIncomeTax"              => { "confidence" => 0.94, "value" => 4500.00 },
        "federalTaxInfo.socialSecurityTax"             => { "confidence" => 0.93, "value" => 1981.77 },
        "federalTaxInfo.medicareTax"                   => { "confidence" => 0.93, "value" => 463.48 },
        "federalTaxInfo.allocatedTips"                 => { "confidence" => 0.80, "value" => 0.00 },
        "federalWageInfo.wagesTipsOtherCompensation"   => { "confidence" => 0.94, "value" => 31964.00 },
        "federalWageInfo.socialSecurityWages"          => { "confidence" => 0.93, "value" => 31964.00 },
        "federalWageInfo.medicareWagesTips"            => { "confidence" => 0.93, "value" => 31964.00 },
        "federalWageInfo.socialSecurityTips"           => { "confidence" => 0.85, "value" => 0.00 },
        "stateTaxesTable.stateName"                    => { "confidence" => 0.90, "value" => "NC" },
        "stateTaxesTable.employerStateIdNumber"        => { "confidence" => 0.85, "value" => 1234567 },
        "stateTaxesTable.stateWagesAndTips"            => { "confidence" => 0.90, "value" => 31964.00 },
        "stateTaxesTable.stateIncomeTax"                => { "confidence" => 0.90, "value" => 1500.00 },
        "stateTaxesTable.localWagesTips"                => { "confidence" => 0.80, "value" => 0.00 },
        "stateTaxesTable.localIncomeTax"                => { "confidence" => 0.80, "value" => 0.00 },
        "stateTaxesTable.localityName"                  => { "confidence" => 0.80, "value" => "" },
        "codes.code"                                   => { "confidence" => 0.80, "value" => "D" },
        "codes.amount"                                 => { "confidence" => 0.80, "value" => 1000.00 },
        "nonqualifiedPlansIncom"                       => { "confidence" => 0.75, "value" => 0.00 },
        "other"                                        => { "confidence" => 0.70, "value" => "N/A" }
      }
    }
  end


  it "is registered as W2" do
    expect(DocAiResult::REGISTRY["W2"]).to eq(described_class)
  end

  describe "typed accessors" do
    it "returns employer_name as FieldValue" do
      expect(w2.employer_name).to be_a(DocAiResult::FieldValue)
      expect(w2.employer_name.value).to eq("University of North Carolina")
    end

    it "returns employer_ein value" do
      expect(w2.employer_ein.value).to eq("56-6001393")
    end

    it "returns employee_first_name value" do
      expect(w2.employee_first_name.value).to eq("Jane")
    end

    it "returns wages_tips_other_compensation value" do
      expect(w2.wages_tips_other_compensation.value).to eq(31964.00)
    end

    it "returns federal_income_tax value" do
      expect(w2.federal_income_tax.value).to eq(4500.00)
    end

    it "returns state_name value" do
      expect(w2.state_name.value).to eq("NC")
    end

    it "returns state_income_tax value" do
      expect(w2.state_income_tax.value).to eq(1500.00)
    end

    it "returns codes.code value" do
      expect(w2.codes_code.value).to eq("D")
    end

    it "handles DocAI typo for nonqualified_plans_income" do
      # Uses literal key "nonqualifiedPlansIncom" (DocAI typo)
      expect(w2.nonqualified_plans_income).to be_a(DocAiResult::FieldValue)
      expect(w2.nonqualified_plans_income.value).to eq(0.00)
    end

    it "returns nil for absent fields" do
      expect(w2.employee_name_suffix).to be_nil
    end
  end

  describe "#to_prefill_fields" do
    subject(:prefill) { w2.to_prefill_fields }

    it "returns key income fields" do
      expect(prefill).to include(
        employer_name:                 "University of North Carolina",
        employer_ein:                  "56-6001393",
        employee_first_name:           "Jane",
        employee_last_name:            "Smith",
        wages_tips_other_compensation: 31964.00,
        federal_income_tax:            4500.00,
        state_name:                    "NC",
        state_income_tax:              1500.00
      )
    end

    it "does not include confidence scores" do
      prefill.each_value do |v|
        expect(v).not_to be_a(DocAiResult::FieldValue)
      end
    end
  end
end
