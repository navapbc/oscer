# frozen_string_literal: true

require "rails_helper"

RSpec.describe DemoAccessGate, type: :controller do
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
        allow(Rails.env).to receive(:local?).and_return(false)
      end

      it "returns false when the flag is disabled" do
        with_demo_certifications_disabled do
          expect(Features.demo_certifications_enabled?).to be(false)
          expect(described_class.access_allowed?).to be(false)
        end
      end

      it "returns true when the flag is enabled" do
        with_demo_certifications_enabled do
          expect(Features.demo_certifications_enabled?).to be(true)
          expect(described_class.access_allowed?).to be(true)
        end
      end
    end
  end

  describe "before_action guard (defense in depth beyond route constraints)" do
    concern = described_class

    controller(ActionController::Base) do
      include concern

      def index
        head :ok
      end
    end

    before do
      allow(Rails.env).to receive(:local?).and_return(false)
    end

    it "returns not_found when access is denied" do
      with_demo_certifications_disabled do
        get :index
      end

      expect(response).to have_http_status(:not_found)
    end

    it "allows the action when the flag is enabled" do
      with_demo_certifications_enabled do
        get :index
      end

      expect(response).to have_http_status(:ok)
    end
  end
end
