# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/demo", type: :request do
  describe "GET /demo" do
    context "when in development/test" do
      it "renders the demo index regardless of the flag" do
        with_demo_certifications_disabled do
          get demo_url
        end
        expect(response).to be_successful
      end
    end

    context "when in a deployed environment" do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("production"))
      end

      it "returns 404 when the flag is disabled" do
        with_demo_certifications_disabled do
          get demo_url
        end
        expect(response).to have_http_status(:not_found)
      end

      it "renders the demo index when the flag is enabled" do
        with_demo_certifications_enabled do
          get demo_url
        end
        expect(response).to be_successful
      end
    end
  end
end
