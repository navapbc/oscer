# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Members", type: :request do
  include Warden::Test::Helpers

  let(:user) { create(:user, :as_admin) }
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

    context "with several certification cases for one member" do
      let(:listed_member_id) { "MEMBER-CASE-LIST" }
      let(:oldest_created_at) { Time.zone.local(2026, 1, 5, 9, 0, 0) }
      let(:middle_created_at) { Time.zone.local(2026, 2, 1, 9, 0, 0) }
      let(:newest_created_at) { Time.zone.local(2026, 3, 10, 12, 0, 0) }
      let(:oldest_case) { build_case(created_at: oldest_created_at) }
      let(:middle_case) { build_case(created_at: middle_created_at) }
      let(:newest_case) { build_case(created_at: newest_created_at) }
      let(:expected_case_ids) { [ newest_case.id, middle_case.id, oldest_case.id ] }
      let(:rendered_case_ids) { response.body.scan(%r{certification_cases/([0-9a-f-]{36})}).flatten }
      let(:rendered_page) { Capybara.string(response.body) }
      let(:rendered_column_names) { rendered_page.all("table thead th").map(&:text) }
      let(:rendered_created_dates) { rendered_page.all("table tbody tr td:nth-child(2)").map(&:text) }

      def build_case(created_at:)
        cert = create(:certification, member_id: listed_member_id)
        CertificationCase.find_by!(certification_id: cert.id).tap do |kase|
          kase.update_column(:created_at, created_at)
        end
      end

      before do
        middle_case
        newest_case
        oldest_case
      end

      it "heads the case list with the case number, creation date and status" do
        get "/staff/members/#{listed_member_id}"

        expect(rendered_column_names).to eq([ "Case No.", "Date created", "Status" ])
      end

      it "shows each case's own creation date" do
        get "/staff/members/#{listed_member_id}"

        expect(rendered_created_dates).to eq(
          [ newest_created_at, middle_created_at, oldest_created_at ].map { |at| at.strftime("%m/%d/%Y") }
        )
      end

      it "lists the cases newest first" do
        get "/staff/members/#{listed_member_id}"

        expect(rendered_case_ids).to eq(expected_case_ids)
      end
    end
  end
end
