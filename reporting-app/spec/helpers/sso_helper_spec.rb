# frozen_string_literal: true

require "rails_helper"

RSpec.describe SsoHelper, type: :helper do
  # Create a test class to include the helper
  let(:helper_class) do
    Class.new do
      include SsoHelper
    end
  end

  let(:helper) { helper_class.new }

  describe "#sso_enabled?" do
    context "when SSO is enabled" do
      before do
        allow(Rails.application.config).to receive(:sso).and_return({ enabled: true })
      end

      it "returns true" do
        expect(helper.sso_enabled?).to be true
      end
    end

    context "when SSO is disabled" do
      before do
        allow(Rails.application.config).to receive(:sso).and_return({ enabled: false })
      end

      it "returns false" do
        expect(helper.sso_enabled?).to be false
      end
    end

    context "when SSO config is not set" do
      before do
        allow(Rails.application.config).to receive(:sso).and_raise(NoMethodError)
      end

      it "returns false" do
        expect(helper.sso_enabled?).to be false
      end
    end

    context "when enabled key is missing" do
      before do
        allow(Rails.application.config).to receive(:sso).and_return({})
      end

      it "returns false" do
        expect(helper.sso_enabled?).to be false
      end
    end
  end
end
