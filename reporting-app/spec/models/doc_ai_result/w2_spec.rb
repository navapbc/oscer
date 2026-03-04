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
        "employerInfo.employerName"                  => { "confidence" => 0.95, "value" => "University of North Carolina" },
        "employerInfo.ein"                            => { "confidence" => 0.94, "value" => "56-6001393" },
        "employerInfo.employerAddress"               => { "confidence" => 0.77, "value" => "123 College Ave" },
        "employerInfo.controlNumber"                 => { "confidence" => 0.96, "value" => "CTL001" },
        "employerInfo.employerZipCode"              => { "confidence" => 0.96, "value" => "27599" },
        "filingInfo.ombNumber"                       => { "confidence" => 0.96, "value" => "1545-0008" },
        "filingInfo.verificationCode"                => { "confidence" => 0.93, "value" => "VER001" },
        "employeeGeneralInfo.firstName"             => { "confidence" => 0.83, "value" => "Jane" },
        "employeeGeneralInfo.employeeLastName"      => { "confidence" => 0.94, "value" => "Smith" },
        "employeeGeneralInfo.employeeAddress"       => { "confidence" => 0.04, "value" => "456 Oak St" },
        "employeeGeneralInfo.employeeZipCode"      => { "confidence" => 0.93, "value" => "27514" },
        "employeeGeneralInfo.ssn"                    => { "confidence" => 0.95, "value" => "XXX-XX-1234" },
        "federalTaxInfo.federalIncomeTax"          => { "confidence" => 0.93, "value" => 4500.00 },
        "federalTaxInfo.socialSecurityTax"         => { "confidence" => 0.92, "value" => 1981.77 },
        "federalTaxInfo.medicareTax"                => { "confidence" => 0.93, "value" => 463.48 },
        "federalTaxInfo.allocatedTips"              => { "confidence" => 0.93, "value" => 0.00 },
        "federalWageInfo.wagesTipsOtherCompensation" => { "confidence" => 0.95, "value" => 31964.00 },
        "federalWageInfo.socialSecurityWages"      => { "confidence" => 0.96, "value" => 31964.00 },
        "federalWageInfo.medicareWagesTips"        => { "confidence" => 0.96, "value" => 31964.00 },
        "federalWageInfo.socialSecurityTips"       => { "confidence" => 0.93, "value" => 0.00 },
        "other"                                       => { "confidence" => 0.93, "value" => "N/A" }
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

    it "returns nil for absent fields" do
      expect(w2.employee_name_suffix).to be_nil
    end
  end

  describe "#to_prefill_fields" do
    subject(:prefill) { w2.to_prefill_fields }

    it "returns all fields" do
      expect(prefill).to eq(
        employer_name:                 "University of North Carolina",
        employer_ein:                  "56-6001393",
        employer_address:              "123 College Ave",
        employer_zip_code:             "27599",
        employer_control_number:       "CTL001",
        omb_number:                    "1545-0008",
        verification_code:             "VER001",
        employee_first_name:           "Jane",
        employee_last_name:            "Smith",
        employee_name_suffix:          nil,
        employee_address:              "456 Oak St",
        employee_zip_code:             "27514",
        employee_ssn:                  "XXX-XX-1234",
        wages_tips_other_compensation: 31964.00,
        federal_income_tax:            4500.00,
        social_security_wages:         31964.00,
        social_security_tax:           1981.77,
        medicare_wages_tips:           31964.00,
        medicare_tax:                  463.48,
        social_security_tips:          0.00,
        allocated_tips:                0.00,
        other:                         "N/A"
      )
    end

    it "does not include confidence scores" do
      prefill.each_value do |v|
        expect(v).not_to be_a(DocAiResult::FieldValue)
      end
    end
  end
end
