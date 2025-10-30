# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/api/health", type: :request do
  include Warden::Test::Helpers

  after do
    Warden.test_reset!
  end

  describe "GET /health" do
    it "renders a successful 'pass' response" do
      get api_health_url
      expect(response).to be_successful
      expect(JSON.parse(response.body)).to eq({ "status" => "pass" })
      expect(response).to match_openapi_doc(OPENAPI_DOC)
    end
  end
end
