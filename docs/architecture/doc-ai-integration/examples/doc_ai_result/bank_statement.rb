# app/models/doc_ai_result/bank_statement.rb
#
# Example showing how to extend DocAiResult for a new document type.
# Steps:
#   1. Create this file under app/models/doc_ai_result/
#   2. Call register with the matchedDocumentClass string returned by the DocAI API
#   3. Implement typed field accessors using field_for
#   4. Implement to_prefill_fields returning { field_name: value } for form prefill
#   5. Add require_relative "doc_ai_result/bank_statement" inside DocAiResult (before REGISTRY.freeze)
#   6. Add "BankStatement" to SUPPORTED_RESULT_CLASSES in DocumentStagingController if applicable
#
class DocAiResult::BankStatement < DocAiResult
  register "BankStatement"

  def account_holder_name = field_for("accountHolderName")
  def account_number      = field_for("accountNumber")
  def statement_date      = field_for("statementDate")
  def closing_balance     = field_for("closingBalance")
  # add further accessors as the DocAI schema defines them

  def to_prefill_fields
    {
      account_holder_name: account_holder_name&.value,
      statement_date:      statement_date&.value,
      closing_balance:     closing_balance&.value
    }
  end
end
