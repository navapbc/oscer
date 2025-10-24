# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Members", type: :request do
  include Warden::Test::Helpers

  let(:user) { create(:user) }
  let(:member_id) { "MEMBER123" }
  let(:member_email) { "test@example.com" }
  let(:certification) do
    create(:certification,
          member_id: member_id,
          member_data: {
            "account_email" => member_email,
            "contact" => {
              "email" => member_email
            }
          },
          certification_requirements: {
            "certification_date" => Date.current,
            "number_of_months_to_certify" => 3
          })
  end
  let(:certification_case) { CertificationCase.find_by(certification_id: certification.id) }

  before do
    login_as user
    # the certification needs to exist to get member data
    certification
  end

  describe "GET /staff/members" do
    it "redirects to search_members_path" do
      get "/staff/members"
      expect(response).to redirect_to(search_members_path)
    end
  end

  describe "GET /staff/members/search" do
    it "shows the search form" do
      get "/staff/members/search"
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Member Search")
      expect(response.body).to include("Email")
    end
  end

  describe "POST /staff/members/search" do
    context "when member exists" do
      it "shows the member in search results" do
        post "/staff/members/search", params: { email: member_email }
        expect(response).to have_http_status(:success)
        expect(response.body).to include(member_id)
        expect(response.body).to include(member_email)
      end
    end
  end

  describe "GET /staff/members/:id" do
    it "shows the member and their certification cases" do
      get "/staff/members/#{member_id}"
      expect(response).to have_http_status(:success)
      expect(response.body).to include(member_id)
      expect(response.body).to include(member_email)
      expect(response.body).to include(certification_case.id.to_s)
    end

    context "when member does not exist" do
      it "returns 404 not found" do
        get "/staff/members/nonexistent-member-id"
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
