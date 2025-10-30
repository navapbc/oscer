# frozen_string_literal: true

require "rails_helper"

RSpec.describe CertificationsController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/staff/certifications").to route_to("certifications#index")
    end

    it "routes to #show" do
      expect(get: "/staff/certifications/1").to route_to("certifications#show", id: "1")
    end

    it "routes to #create" do
      expect(post: "/staff/certifications").to route_to("certifications#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/staff/certifications/1").to route_to("certifications#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/staff/certifications/1").to route_to("certifications#update", id: "1")
    end
  end
end
