# frozen_string_literal: true

require "rails_helper"

RSpec.describe DocAiResult::Payslip do
  subject(:payslip) { described_class.build(response) }

  let(:response) do
    {
      "job_id"               => "abc-123",
      "status"               => "completed",
      "matchedDocumentClass" => "Payslip",
      "fields" => {
        "payperiodstartdate"         => { "confidence" => 0.91, "value" => "2017-07-10" },
        "payperiodenddate"           => { "confidence" => 0.90, "value" => "2017-07-24" },
        "paydate"                    => { "confidence" => 0.88, "value" => "2017-07-28" },
        "currentgrosspay"            => { "confidence" => 0.93, "value" => 1627.74 },
        "currentnetpay"              => { "confidence" => 0.92, "value" => 1200.00 },
        "currenttotaldeductions"     => { "confidence" => 0.85, "value" => 427.74 },
        "ytdgrosspay"                => { "confidence" => 0.94, "value" => 9766.44 },
        "ytdnetpay"                  => { "confidence" => 0.91, "value" => 7200.00 },
        "ytdfederaltax"              => { "confidence" => 0.89, "value" => 980.50 },
        "ytdstatetax"                => { "confidence" => 0.87, "value" => 320.10 },
        "ytdcitytax"                 => { "confidence" => 0.85, "value" => 50.00 },
        "ytdtotaldeductions"         => { "confidence" => 0.86, "value" => 2566.44 },
        "regularhourlyrate"          => { "confidence" => 0.95, "value" => 20.00 },
        "holidayhourlyrate"          => { "confidence" => 0.80, "value" => 30.00 },
        "federalfilingstatus"        => { "confidence" => 0.91, "value" => "Single" },
        "statefilingstatus"          => { "confidence" => 0.88, "value" => "Single" },
        "employeenumber"             => { "confidence" => 0.97, "value" => "EMP001" },
        "payrollnumber"              => { "confidence" => 0.97, "value" => "PAY001" },
        "currency"                   => { "confidence" => 0.99, "value" => "USD" },
        "employeename.firstname"     => { "confidence" => 0.95, "value" => "John" },
        "employeename.lastname"      => { "confidence" => 0.95, "value" => "Doe" },
        "employeeaddress.line1"      => { "confidence" => 0.90, "value" => "123 Main St" },
        "employeeaddress.city"       => { "confidence" => 0.90, "value" => "Springfield" },
        "employeeaddress.state"      => { "confidence" => 0.92, "value" => "IL" },
        "employeeaddress.zipcode"    => { "confidence" => 0.93, "value" => "62701" },
        "companyname"                => { "confidence" => 0.92, "value" => "Acme Payroll LLC" },
        "federaltaxes.itemdescription" => { "confidence" => 0.90, "value" => "Federal Income Tax" },
        "federaltaxes.ytd"             => { "confidence" => 0.90, "value" => 980.50 },
        "federaltaxes.period"          => { "confidence" => 0.90, "value" => 150.00 },
        "isGrossPayValid"              => { "confidence" => 0.87, "value" => true },
        "isYtdGrossPayHighest"         => { "confidence" => 0.85, "value" => false },
        "areFieldNamesSufficient"      => { "confidence" => 0.88, "value" => true }
      }
    }
  end


  it "is registered as Payslip" do
    expect(DocAiResult::REGISTRY["Payslip"]).to eq(described_class)
  end

  describe "typed accessors" do
    it "returns pay_period_start_date as FieldValue" do
      expect(payslip.pay_period_start_date).to be_a(DocAiResult::FieldValue)
      expect(payslip.pay_period_start_date.value).to eq("2017-07-10")
    end

    it "returns current_gross_pay value" do
      expect(payslip.current_gross_pay.value).to eq(1627.74)
    end

    it "returns ytd_gross_pay value" do
      expect(payslip.ytd_gross_pay.value).to eq(9766.44)
    end

    it "returns employee_first_name value" do
      expect(payslip.employee_first_name.value).to eq("John")
    end

    it "returns employee_last_name value" do
      expect(payslip.employee_last_name.value).to eq("Doe")
    end

    it "returns federal_taxes fields" do
      expect(payslip.federal_taxes_description.value).to eq("Federal Income Tax")
      expect(payslip.federal_taxes_ytd.value).to eq(980.50)
      expect(payslip.federal_taxes_period.value).to eq(150.00)
    end

    it "returns nil for absent fields" do
      expect(payslip.employee_middle_name).to be_nil
    end

    it "returns company_name value" do
      expect(payslip.company_name.value).to eq("Acme Payroll LLC")
    end

    it "returns company_name_value as stripped string" do
      expect(payslip.company_name_value).to eq("Acme Payroll LLC")
    end

    it "treats whitespace-only companyname as nil via company_name_value" do
      fields = response["fields"].deep_dup
      fields["companyname"] = { "confidence" => 0.5, "value" => "   " }
      expect(described_class.build(response.merge("fields" => fields)).company_name_value).to be_nil
    end
  end

  describe "boolean accessors" do
    it "gross_pay_valid? returns true when value is true" do
      expect(payslip.gross_pay_valid?).to be true
    end

    it "ytd_gross_pay_highest? returns false when value is false" do
      expect(payslip.ytd_gross_pay_highest?).to be false
    end

    it "field_names_sufficient? returns true when value is true" do
      expect(payslip.field_names_sufficient?).to be true
    end
  end

  describe "#to_prefill_fields" do
    subject(:prefill) { payslip.to_prefill_fields }

    it "returns a hash of field values" do
      expect(prefill).to include(
        pay_period_start_date: "2017-07-10",
        current_gross_pay:     1627.74,
        ytd_gross_pay:         9766.44,
        ytd_federal_tax:       980.50,
        ytd_city_tax:          50.00,
        employee_first_name:   "John",
        employee_last_name:    "Doe",
        company_name:          "Acme Payroll LLC"
      )
    end

    it "does not include confidence scores" do
      prefill.each_value do |v|
        expect(v).not_to be_a(DocAiResult::FieldValue)
      end
    end

    it "returns nil for absent optional fields" do
      expect(prefill[:employee_address_line2]).to be_nil
    end
  end
end
