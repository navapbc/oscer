# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Determinable, type: :model do
  let(:certification) { create(:certification) }
  let(:user) { create(:user) }

  RSpec.shared_examples "a manual exemption" do |reason_code, outcome|
    let(:params) do
      {
        decision_method: :manual,
        reasons: [ Determination::REASON_CODE_MAPPING[reason_code] ],
        outcome:,
        determination_data: { foo: :bar },
        determined_at: Time.now,
        actor: user
      }
    end

    it "adds the actor as determined_by for the determination" do
      determination = certification.record_determination!(**params)
      expect(determination.determined_by_id).to eq user.id
    end

    it "creates an audit log" do
      expect do
        certification.record_determination!(**params)
      end.to change { Strata::AuditLine.where(subject: certification, actor: user, action: "case.exemption.approved").count }.by(1)
    end
  end

  RSpec.shared_examples "an automated exemption" do |reason_code, outcome|
    let(:params) do
      {
        decision_method: :automated,
        reasons: [ Determination::REASON_CODE_MAPPING[reason_code] ],
        outcome:,
        determination_data: { foo: :bar },
        determined_at: Time.now,
        actor: ExemptionDeterminationService
      }
    end

    it "adds the actor as determined_by for the determination" do
      determination = certification.record_determination!(**params)
      expect(determination.determined_by_id).to be_nil
    end

    it "creates an audit log" do
      expect do
        certification.record_determination!(**params)
      end.to change { Strata::AuditLine.where(subject: certification, actor_type: ExemptionDeterminationService.name, action: "case.exemption.approved").count }.by(1)
    end
  end

  describe 'Exemptions' do
    %i[age_under_19 age_over_65 is_pregnant is_american_indian_or_alaska_native exemption_request_compliant is_veteran_with_disability].each do |reason_code|
      it_behaves_like "a manual exemption", reason_code, :exempt
      it_behaves_like "an automated exemption", reason_code, :exempt
    end
  end
end
