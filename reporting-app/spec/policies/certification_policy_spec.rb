# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CertificationPolicy, type: :policy do
  let(:current_user) { create(:user) }
  let(:staff_user) { create(:user) }
  let(:state_system_user) { Api::Client.new }

  let(:record) { create(:certification) }

  let(:resolved_scope) do
    described_class::Scope.new(current_user, Certification.all).resolve
  end

  context "when unauthenticated" do
    let(:current_user) { nil }

    it "raises a Pundit::NotAuthorizedError" do
      expect { described_class.new(current_user, record) }.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  context "when Staff" do
    let(:current_user) { :staff_user }

    it "forbids the destroy action" do
      expect(described_class.new(current_user, record)).to forbid_action(:destroy)
    end

    it 'includes all records in the resolved scope' do
      expect(resolved_scope).to include(record)
    end
  end

  context "when State System" do
    let(:current_user) { :state_system_user }

    it "forbids the destroy action" do
      expect(described_class.new(current_user, record)).to forbid_action(:destroy)
    end

    it 'includes all records in the resolved scope' do
      expect(resolved_scope).to include(record)
    end
  end
end
