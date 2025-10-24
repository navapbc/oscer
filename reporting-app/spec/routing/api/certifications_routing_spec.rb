# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::CertificationsController, type: :routing do
  describe "API routing" do
    it "routes to #show" do
      expect(get: "/api/certifications/1").to route_to("api/certifications#show", id: "1")
    end

    it "routes to #create" do
      expect(post: "/api/certifications").to route_to("api/certifications#create")
    end
  end
end
