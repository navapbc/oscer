# frozen_string_literal: true

class Demo::DocumentStagingController < ApplicationController
  before_action :authenticate_user!

  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  skip_before_action :verify_authenticity_token

  # POST /demo/document_staging/validate
  # Test-support endpoint: immediately marks staged documents as validated with
  # mock February 2026 payslip data, bypassing the async DocAI service.
  def validate
    ids = Array(params[:ids]).reject(&:blank?)

    StagedDocument.where(id: ids).where(status: %w[pending failed]).update_all( # rubocop:disable Rails/SkipsModelValidations
      status: "validated",
      doc_ai_matched_class: "Payslip",
      extracted_fields: mock_payslip_fields,
      validated_at: Time.current
    )

    head :no_content
  end

  private

  def mock_payslip_fields
    {
      "payperiodstartdate" => { "value" => "2026-02-01", "confidence" => 0.95 },
      "payperiodenddate"   => { "value" => "2026-02-28", "confidence" => 0.95 },
      "paydate"            => { "value" => "2026-02-28", "confidence" => 0.95 },
      "currentgrosspay"    => { "value" => "5000.00",    "confidence" => 0.95 },
      "currentnetpay"      => { "value" => "3800.00",    "confidence" => 0.90 }
    }
  end
end
