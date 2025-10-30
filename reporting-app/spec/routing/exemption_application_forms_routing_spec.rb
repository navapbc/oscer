# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExemptionApplicationFormsController, type: :routing do
  describe "routing" do
    it "routes to #new" do
      expect(get: "/exemption_application_forms/new").to route_to("exemption_application_forms#new")
    end

    it "routes to #show" do
      expect(get: "/exemption_application_forms/1").to route_to("exemption_application_forms#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/exemption_application_forms/1/edit").to route_to("exemption_application_forms#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/exemption_application_forms").to route_to("exemption_application_forms#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/exemption_application_forms/1").to route_to("exemption_application_forms#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/exemption_application_forms/1").to route_to("exemption_application_forms#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/exemption_application_forms/1").to route_to("exemption_application_forms#destroy", id: "1")
    end

    it "routes to #review" do
      expect(get: "/exemption_application_forms/1/review").to route_to("exemption_application_forms#review", id: "1")
    end

    it "routes to #submit" do
      expect(post: "/exemption_application_forms/1/submit").to route_to("exemption_application_forms#submit", id: "1")
    end

    it "routes to #documents" do
      expect(get: "/exemption_application_forms/1/documents").to route_to("exemption_application_forms#documents", id: "1")
    end

    it "routes to #upload_documents" do
      expect(post: "/exemption_application_forms/1/upload_documents").to route_to("exemption_application_forms#upload_documents", id: "1")
    end
  end
end
