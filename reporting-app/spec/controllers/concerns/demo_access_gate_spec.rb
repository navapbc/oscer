# frozen_string_literal: true

require "rails_helper"

RSpec.describe DemoAccessGate do
  describe ".access_allowed?" do
    context "when Rails.env.local?" do
      it "returns true even when the flag is disabled" do
        with_demo_certifications_disabled do
          expect(described_class.access_allowed?).to be(true)
        end
      end
    end

    context "when not local (deployed environment)" do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("production"))
      end

      it "returns false when the flag is disabled" do
        with_demo_certifications_disabled do
          expect(described_class.access_allowed?).to be(false)
        end
      end

      it "returns true when the flag is enabled" do
        with_demo_certifications_enabled do
          expect(described_class.access_allowed?).to be(true)
        end
      end
    end
  end
end
