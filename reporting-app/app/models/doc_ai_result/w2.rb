# frozen_string_literal: true

class DocAiResult::W2 < DocAiResult
  register "W2"

  # --- Employer Info ---
  def employer_address        = field_for("employer_info.employer_address")
  def employer_control_number = field_for("employer_info.control_number")
  def employer_name           = field_for("employer_info.employer_name")
  def employer_ein            = field_for("employer_info.ein")
  def employer_zip_code       = field_for("employer_info.employer_zip_code")

  # --- Filing Info ---
  def omb_number              = field_for("filing_info.omb_number")
  def verification_code       = field_for("filing_info.verification_code")

  # --- Employee Info ---
  def employee_name_suffix    = field_for("employee_general_info.employee_name_suffix")
  def employee_address        = field_for("employee_general_info.employee_address")
  def employee_last_name      = field_for("employee_general_info.employee_last_name")
  def employee_zip_code       = field_for("employee_general_info.employee_zip_code")
  def employee_first_name     = field_for("employee_general_info.first_name")
  def employee_ssn            = field_for("employee_general_info.ssn")

  # --- Federal Tax ---
  def federal_income_tax      = field_for("federal_tax_info.federal_income_tax")
  def allocated_tips          = field_for("federal_tax_info.allocated_tips")
  def social_security_tax     = field_for("federal_tax_info.social_security_tax")
  def medicare_tax            = field_for("federal_tax_info.medicare_tax")

  # --- Federal Wages ---
  def social_security_tips          = field_for("federal_wage_info.social_security_tips")
  def wages_tips_other_compensation = field_for("federal_wage_info.wages_tips_other_compensation")
  def medicare_wages_tips           = field_for("federal_wage_info.medicare_wages_tips")
  def social_security_wages         = field_for("federal_wage_info.social_security_wages")

  # --- State Taxes ---
  def state_name                = field_for("state_taxes_table.state_name")
  def employer_state_id_number  = field_for("state_taxes_table.employer_state_id_number")
  def state_wages_and_tips      = field_for("state_taxes_table.state_wages_and_tips")
  def state_income_tax          = field_for("state_taxes_table.state_income_tax")
  def local_wages_tips          = field_for("state_taxes_table.local_wages_tips")
  def local_income_tax          = field_for("state_taxes_table.local_income_tax")
  def locality_name             = field_for("state_taxes_table.locality_name")

  # --- Codes ---
  def codes_code                = field_for("codes.code")
  def codes_amount              = field_for("codes.amount")

  # --- Other ---
  def other                         = field_for("other")
  def nonqualified_plans_income     = field_for("nonqualified_plans_incom") # DocAI typo — literal key from schema

  # Returns a flat hash of { field_name: value } for form prefill.
  def to_prefill_fields
    {
      employer_name:                 employer_name&.value,
      employer_ein:                  employer_ein&.value,
      employer_address:              employer_address&.value,
      employer_zip_code:             employer_zip_code&.value,
      employer_control_number:       employer_control_number&.value,
      omb_number:                    omb_number&.value,
      verification_code:             verification_code&.value,
      employee_first_name:           employee_first_name&.value,
      employee_last_name:            employee_last_name&.value,
      employee_name_suffix:          employee_name_suffix&.value,
      employee_address:              employee_address&.value,
      employee_zip_code:             employee_zip_code&.value,
      employee_ssn:                  employee_ssn&.value,
      wages_tips_other_compensation: wages_tips_other_compensation&.value,
      federal_income_tax:            federal_income_tax&.value,
      social_security_wages:         social_security_wages&.value,
      social_security_tax:           social_security_tax&.value,
      medicare_wages_tips:           medicare_wages_tips&.value,
      medicare_tax:                  medicare_tax&.value,
      social_security_tips:          social_security_tips&.value,
      allocated_tips:                allocated_tips&.value,
      state_name:                    state_name&.value,
      employer_state_id_number:      employer_state_id_number&.value,
      state_wages_and_tips:          state_wages_and_tips&.value,
      state_income_tax:              state_income_tax&.value,
      local_wages_tips:              local_wages_tips&.value,
      local_income_tax:              local_income_tax&.value,
      locality_name:                 locality_name&.value,
      codes_code:                    codes_code&.value,
      codes_amount:                  codes_amount&.value,
      nonqualified_plans_income:     nonqualified_plans_income&.value,
      other:                         other&.value
    }
  end
end
