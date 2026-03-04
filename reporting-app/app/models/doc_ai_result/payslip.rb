# frozen_string_literal: true

class DocAiResult::Payslip < DocAiResult
  register "Payslip"

  # --- Pay period ---
  def pay_period_start_date    = field_for("payperiodstartdate")
  def pay_period_end_date      = field_for("payperiodenddate")
  def pay_date                 = field_for("paydate")

  # --- Current period pay ---
  def current_gross_pay        = field_for("currentgrosspay")
  def current_net_pay          = field_for("currentnetpay")
  def current_total_deductions = field_for("currenttotaldeductions")

  # --- Year-to-date ---
  def ytd_gross_pay            = field_for("ytdgrosspay")
  def ytd_net_pay              = field_for("ytdnetpay")
  def ytd_federal_tax          = field_for("ytdfederaltax")
  def ytd_state_tax            = field_for("ytdstatetax")
  def ytd_city_tax             = field_for("ytdcitytax")
  def ytd_total_deductions     = field_for("ytdtotaldeductions")

  # --- Rates ---
  def regular_hourly_rate      = field_for("regularhourlyrate")
  def holiday_hourly_rate      = field_for("holidayhourlyrate")

  # --- Filing status ---
  def federal_filing_status    = field_for("federalfilingstatus")
  def state_filing_status      = field_for("statefilingstatus")

  # --- Identifiers ---
  def employee_number          = field_for("employeenumber")
  def payroll_number           = field_for("payrollnumber")
  def currency                 = field_for("currency")

  # --- Employee name ---
  def employee_first_name      = field_for("employeename.firstname")
  def employee_middle_name     = field_for("employeename.middlename")
  def employee_last_name       = field_for("employeename.lastname")
  def employee_suffix_name     = field_for("employeename.suffixname")

  # --- Employee address ---
  def employee_address_line1   = field_for("employeeaddress.line1")
  def employee_address_line2   = field_for("employeeaddress.line2")
  def employee_address_city    = field_for("employeeaddress.city")
  def employee_address_state   = field_for("employeeaddress.state")
  def employee_address_zipcode = field_for("employeeaddress.zipcode")

  # --- Company address ---
  def company_address_line1    = field_for("companyaddress.line1")
  def company_address_line2    = field_for("companyaddress.line2")
  def company_address_city     = field_for("companyaddress.city")
  def company_address_state    = field_for("companyaddress.state")
  def company_address_zipcode  = field_for("companyaddress.zipcode")

  # --- Taxes (Nested/Repeated Fields) ---
  def federal_taxes_description = field_for("federaltaxes.itemdescription")
  def federal_taxes_ytd         = field_for("federaltaxes.ytd")
  def federal_taxes_period      = field_for("federaltaxes.period")

  def state_taxes_description   = field_for("statetaxes.itemdescription")
  def state_taxes_ytd           = field_for("statetaxes.ytd")
  def state_taxes_period        = field_for("statetaxes.period")

  def city_taxes_description    = field_for("citytaxes.itemdescription")
  def city_taxes_ytd            = field_for("citytaxes.ytd")
  def city_taxes_period         = field_for("citytaxes.period")

  # --- Validation flags (boolean predicates — unwrap value directly) ---
  def gross_pay_valid?        = field_for("isGrossPayValid")&.value == true
  def ytd_gross_pay_highest?  = field_for("isYtdGrossPayHighest")&.value == true
  def field_names_sufficient? = field_for("areFieldNamesSufficient")&.value == true

  # Returns a flat hash of { field_name: value } for form prefill.
  # Confidence scores are not included — they are available in the persisted extracted_fields JSONB.
  def to_prefill_fields
    {
      pay_period_start_date:    pay_period_start_date&.value,
      pay_period_end_date:      pay_period_end_date&.value,
      pay_date:                 pay_date&.value,
      current_gross_pay:        current_gross_pay&.value,
      current_net_pay:          current_net_pay&.value,
      current_total_deductions: current_total_deductions&.value,
      ytd_gross_pay:            ytd_gross_pay&.value,
      ytd_net_pay:              ytd_net_pay&.value,
      ytd_federal_tax:          ytd_federal_tax&.value,
      ytd_state_tax:            ytd_state_tax&.value,
      ytd_city_tax:             ytd_city_tax&.value,
      ytd_total_deductions:     ytd_total_deductions&.value,
      regular_hourly_rate:      regular_hourly_rate&.value,
      holiday_hourly_rate:      holiday_hourly_rate&.value,
      federal_filing_status:    federal_filing_status&.value,
      state_filing_status:      state_filing_status&.value,
      employee_number:          employee_number&.value,
      payroll_number:           payroll_number&.value,
      currency:                 currency&.value,
      employee_first_name:      employee_first_name&.value,
      employee_middle_name:     employee_middle_name&.value,
      employee_last_name:       employee_last_name&.value,
      employee_suffix_name:     employee_suffix_name&.value,
      employee_address_line1:   employee_address_line1&.value,
      employee_address_line2:   employee_address_line2&.value,
      employee_address_city:    employee_address_city&.value,
      employee_address_state:   employee_address_state&.value,
      employee_address_zipcode: employee_address_zipcode&.value,
      company_address_line1:    company_address_line1&.value,
      company_address_line2:    company_address_line2&.value,
      company_address_city:     company_address_city&.value,
      company_address_state:    company_address_state&.value,
      company_address_zipcode:  company_address_zipcode&.value
    }
  end
end
