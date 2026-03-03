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
        "employer_info.employer_name"                  => { "confidence" => 0.92, "value" => "University of North Carolina" },
        "employer_info.ein"                            => { "confidence" => 0.95, "value" => "56-6001393" },
        "employer_info.employer_address"               => { "confidence" => 0.88, "value" => "123 College Ave" },
        "employer_info.control_number"                 => { "confidence" => 0.80, "value" => "CTL001" },
        "employer_info.employer_zip_code"              => { "confidence" => 0.90, "value" => "27599" },
        "filing_info.omb_number"                       => { "confidence" => 0.99, "value" => "1545-0008" },
        "filing_info.verification_code"                => { "confidence" => 0.75, "value" => "VER001" },
        "employee_general_info.first_name"             => { "confidence" => 0.96, "value" => "Jane" },
        "employee_general_info.employee_last_name"      => { "confidence" => 0.96, "value" => "Smith" },
        "employee_general_info.employee_address"       => { "confidence" => 0.88, "value" => "456 Oak St" },
        "employee_general_info.employee_zip_code"      => { "confidence" => 0.90, "value" => "27514" },
        "employee_general_info.ssn"                    => { "confidence" => 0.97, "value" => "XXX-XX-1234" },
        "federal_tax_info.federal_income_tax"          => { "confidence" => 0.94, "value" => 4500.00 },
        "federal_tax_info.social_security_tax"         => { "confidence" => 0.93, "value" => 1981.77 },
        "federal_tax_info.medicare_tax"                => { "confidence" => 0.93, "value" => 463.48 },
        "federal_tax_info.allocated_tips"              => { "confidence" => 0.80, "value" => 0.00 },
        "federal_wage_info.wages_tips_other_compensation" => { "confidence" => 0.94, "value" => 31964.00 },
        "federal_wage_info.social_security_wages"      => { "confidence" => 0.93, "value" => 31964.00 },
        "federal_wage_info.medicare_wages_tips"        => { "confidence" => 0.93, "value" => 31964.00 },
        "federal_wage_info.social_security_tips"       => { "confidence" => 0.85, "value" => 0.00 },
        "state_taxes_table.state_name"                 => { "confidence" => 0.90, "value" => "NC" },
        "state_taxes_table.employer_state_id_number"   => { "confidence" => 0.85, "value" => 1234567 },
        "state_taxes_table.state_wages_and_tips"       => { "confidence" => 0.90, "value" => 31964.00 },
        "state_taxes_table.state_income_tax"           => { "confidence" => 0.90, "value" => 1500.00 },
        "state_taxes_table.local_wages_tips"           => { "confidence" => 0.80, "value" => 0.00 },
        "state_taxes_table.local_income_tax"           => { "confidence" => 0.80, "value" => 0.00 },
        "state_taxes_table.locality_name"              => { "confidence" => 0.80, "value" => "" },
        "codes.code"                                  => { "confidence" => 0.80, "value" => "D" },
        "codes.amount"                                => { "confidence" => 0.80, "value" => 1000.00 },
        "nonqualified_plans_incom"                    => { "confidence" => 0.75, "value" => 0.00 },
        "other"                                       => { "confidence" => 0.70, "value" => "N/A" }
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
      # Uses literal key "nonqualified_plans_incom" (DocAI typo)
      expect(w2.nonqualified_plans_income).to be_a(DocAiResult::FieldValue)
      expect(w2.nonqualified_plans_income.value).to eq(0.00)
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
        state_name:                    "NC",
        employer_state_id_number:      1234567,
        state_wages_and_tips:          31964.00,
        state_income_tax:              1500.00,
        local_wages_tips:              0.00,
        local_income_tax:              0.00,
        locality_name:                 "",
        codes_code:                    "D",
        codes_amount:                  1000.00,
        nonqualified_plans_income:     0.00,
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
