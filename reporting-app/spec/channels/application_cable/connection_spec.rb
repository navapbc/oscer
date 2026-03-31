# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationCable::Connection, type: :channel do
  let(:user) { create(:user) }

  context "when authenticated" do
    it "connects and identifies current_user" do
      connect "/cable", env: { "warden" => double(user: user) }
      expect(connection.current_user).to eq(user)
    end
  end

  context "when unauthenticated" do
    it "rejects the connection" do
      expect { connect "/cable", env: { "warden" => double(user: nil) } }
        .to have_rejected_connection
    end
  end
end
