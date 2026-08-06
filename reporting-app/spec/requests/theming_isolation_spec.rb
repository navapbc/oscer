# frozen_string_literal: true

require 'rails_helper'

# Proves the client and staff surfaces load independent stylesheet bundles
# (Azure DevOps PBI 69889 / SS-69889). A client-only override lives in
# "client.css" and a staff-only override in "staff.css"; each surface loads
# exactly one of them, on top of the shared "application" bundle. This is the
# structural guarantee that a styling change scoped to one surface cannot
# affect the other.
RSpec.describe "Client/staff theming isolation", type: :request do
  include Warden::Test::Helpers

  after { Warden.test_reset! }

  # Normalize a stylesheet href to its logical bundle name, dropping the
  # sprockets digest and extension: "/assets/client-abc123.css" -> "client".
  def linked_bundles(body)
    Nokogiri::HTML(body)
      .css('link[rel="stylesheet"]')
      .map { |link| File.basename(link["href"].to_s).sub(/(-[0-9a-f]+)?\.css.*\z/, "") }
  end

  describe "the client (member-facing) surface" do
    let(:member_data) { build(:certification_member_data, :with_account_email) }
    let(:user) { create(:user, email: member_data.account_email) }

    before do
      allow(Strata::EventManager).to receive(:publish)
      create(:certification, member_data: member_data)
      login_as user
    end

    it "loads the shared and client bundles but not the staff bundle" do
      get "/dashboard"

      expect(response).to be_successful
      bundles = linked_bundles(response.body)
      expect(bundles).to include("application", "client")
      expect(bundles).not_to include("staff")
      expect(bundles.index("application")).to be < bundles.index("client")
    end
  end

  describe "the staff-facing surface" do
    before { login_as create(:user, :as_admin) }

    it "loads the shared and staff bundles but not the client bundle" do
      get "/staff/users"

      expect(response).to be_successful
      bundles = linked_bundles(response.body)
      expect(bundles).to include("application", "staff")
      expect(bundles).not_to include("client")
      expect(bundles.index("application")).to be < bundles.index("staff")
    end
  end
end
