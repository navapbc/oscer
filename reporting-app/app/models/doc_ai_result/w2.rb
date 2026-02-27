# frozen_string_literal: true

# app/models/doc_ai_result/w2.rb
class DocAiResult::W2 < DocAiResult
  register "W2"

  # --- Employer Info ---
  def employer_address        = field_for("employerInfo.employerAddress")
  def employer_control_number = field_for("employerInfo.controlNumber")
  def employer_name           = field_for("employerInfo.employerName")
  def employer_ein            = field_for("employerInfo.ein")
  def employer_zip_code       = field_for("employerInfo.employerZipCode")

  # --- Filing Info ---
  def omb_number              = field_for("filingInfo.ombNumber")
  def verification_code       = field_for("filingInfo.verificationCode")

  # --- Employee Info ---
  def employee_name_suffix    = field_for("employeeGeneralInfo.employeeNameSuffix")
  def employee_address        = field_for("employeeGeneralInfo.employeeAddress")
  def employee_last_name      = field_for("employeeGeneralInfo.employeeLastName")
  def employee_zip_code       = field_for("employeeGeneralInfo.employeeZipCode")
  def employee_first_name     = field_for("employeeGeneralInfo.firstName")
  def employee_ssn            = field_for("employeeGeneralInfo.ssn")

  # --- Federal Tax ---
  def federal_income_tax      = field_for("federalTaxInfo.federalIncomeTax")
  def allocated_tips          = field_for("federalTaxInfo.allocatedTips")
  def social_security_tax     = field_for("federalTaxInfo.socialSecurityTax")
  def medicare_tax            = field_for("federalTaxInfo.medicareTax")

  # --- Federal Wages ---
  def social_security_tips          = field_for("federalWageInfo.socialSecurityTips")
  def wages_tips_other_compensation = field_for("federalWageInfo.wagesTipsOtherCompensation")
  def medicare_wages_tips           = field_for("federalWageInfo.medicareWagesTips")
  def social_security_wages         = field_for("federalWageInfo.socialSecurityWages")

  # --- State Taxes ---
  def state_name                = field_for("stateTaxesTable.stateName")
  def employer_state_id_number  = field_for("stateTaxesTable.employerStateIdNumber")
  def state_wages_and_tips      = field_for("stateTaxesTable.stateWagesAndTips")
  def state_income_tax          = field_for("stateTaxesTable.stateIncomeTax")
  def local_wages_tips          = field_for("stateTaxesTable.localWagesTips")
  def local_income_tax          = field_for("stateTaxesTable.localIncomeTax")
  def locality_name             = field_for("stateTaxesTable.localityName")

  # --- Codes ---
  def codes_code                = field_for("codes.code")
  def codes_amount              = field_for("codes.amount")

  # --- Other ---
  def other                         = field_for("other")
  def nonqualified_plans_income     = field_for("nonqualifiedPlansIncom") # DocAI typo — literal key

  # Returns a flat hash of { field_name: value } for form prefill.
  def to_prefill_fields
    {
      employer_name:                 employer_name&.value,
      employer_ein:                  employer_ein&.value,
      employer_address:              employer_address&.value,
      employee_first_name:           employee_first_name&.value,
      employee_last_name:            employee_last_name&.value,
      employee_address:              employee_address&.value,
      wages_tips_other_compensation: wages_tips_other_compensation&.value,
      federal_income_tax:            federal_income_tax&.value,
      social_security_wages:         social_security_wages&.value,
      social_security_tax:           social_security_tax&.value,
      medicare_wages_tips:           medicare_wages_tips&.value,
      medicare_tax:                  medicare_tax&.value,
      state_name:                    state_name&.value,
      state_income_tax:              state_income_tax&.value
    }
  end
end
