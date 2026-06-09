# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Determinable, type: :model do
  let(:certification) { create(:certification) }
  let(:user) { create(:user) }

  before { stub_const("MockSubmitter", Class.new { include Strata::VirtualActor }) }

  RSpec.shared_examples "a submitted determination" do |reason_code|
    let(:base_params) do
      {
        reasons: [ Determination::REASON_CODE_MAPPING[reason_code] ],
        outcome: :compliant,
        determination_data: { foo: :bar },
        determined_at: Time.now
      }
    end

    context "when submitted by user" do
      let(:params) { base_params.merge({ decision_method: :manual, actor: user }) }

      it "adds the actor as determined_by for the determination" do
        determination = certification.record_determination!(**params)
        expect(determination.determined_by_id).to eq user.id
      end

      it "adds the user as actor to the audit log" do
        expect do
          certification.record_determination!(**params)
        end.to change { Strata::AuditLine.where(subject: certification, actor: user).count }.by(1)
      end
    end

    context "when submitted by exemption service" do
      let(:params) { base_params.merge({ decision_method: :automated, actor: MockSubmitter }) }

      it "adds the actor as determined_by for the determination" do
        determination = certification.record_determination!(**params)
        expect(determination.determined_by_id).to be_nil
      end

      it "adds the submitter as actor to the audit log" do
        expect do
          certification.record_determination!(**params)
        end.to change { Strata::AuditLine.where(subject: certification, actor_type: MockSubmitter.name).count }.by(1)
      end
    end
  end

  RSpec.shared_examples "an exemption" do |reason_code|
    let(:base_params) do
      {
        reasons: [ Determination::REASON_CODE_MAPPING[reason_code] ],
        decision_method: :automated,
        determination_data: { foo: :bar },
        determined_at: Time.now
      }
    end

    context :compliant do
      let(:params) { base_params.merge({ outcome: :compliant }) }

      it "creates an audit log" do
        expect do
          certification.record_determination!(**params)
        end.to change { Strata::AuditLine.where(subject: certification, actor: nil, action: "case.exemption.approved").count }.by(1)
      end
    end

    context :exempt do
      let(:params) { base_params.merge({ outcome: :exempt }) }

      it "creates an audit log" do
        expect do
          certification.record_determination!(**params)
        end.to change { Strata::AuditLine.where(subject: certification, actor: nil, action: "case.exemption.approved").count }.by(1)
      end
    end

    context :not_compliant do
      let(:params) { base_params.merge({ outcome: :not_compliant }) }

      it "creates an audit log" do
        expect do
          certification.record_determination!(**params)
        end.to change { Strata::AuditLine.where(subject: certification, actor: nil, action: "case.exemption.denied").count }.by(1)
      end
    end
  end

  RSpec.shared_examples "an activity report" do |reason_code|
    let(:base_params) do
      {
        reasons: [ Determination::REASON_CODE_MAPPING[reason_code] ],
        decision_method: :automated,
        determination_data: { foo: :bar },
        determined_at: Time.now
      }
    end

    context :compliant do
      let(:params) { base_params.merge({ outcome: :compliant }) }

      it "creates an audit log" do
        expect do
          certification.record_determination!(**params)
        end.to change { Strata::AuditLine.where(subject: certification, actor: nil, action: "case.activity_report.approved").count }.by(1)
      end
    end

    context :not_compliant do
      let(:params) { base_params.merge({ outcome: :not_compliant }) }

      it "creates an audit log" do
        expect do
          certification.record_determination!(**params)
        end.to change { Strata::AuditLine.where(subject: certification, actor: nil, action: "case.activity_report.denied").count }.by(1)
      end
    end
  end

  describe 'Exemption reason' do
    %i[age_under_19 age_over_65 is_pregnant is_american_indian_or_alaska_native exemption_request_compliant is_veteran_with_disability].each do |reason_code|
      context reason_code do
        it_behaves_like "a submitted determination", reason_code
        it_behaves_like "an exemption", reason_code
      end
    end
  end

  describe 'Activity reason' do
    %i[income_reported_compliant income_reported_insufficient hours_reported_compliant hours_reported_insufficient].each do |reason_code|
      it_behaves_like "a submitted determination", reason_code
      it_behaves_like "an activity report", reason_code
    end
  end
end
