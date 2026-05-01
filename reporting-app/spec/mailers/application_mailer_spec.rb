# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationMailer, type: :mailer do
  describe "View paths" do
    it "first resolves to app/views/overrides" do
      first_view_path = described_class.new.view_paths.first
      expect(first_view_path.path).to eq File.expand_path("app/views/overrides")
    end
  end
end
