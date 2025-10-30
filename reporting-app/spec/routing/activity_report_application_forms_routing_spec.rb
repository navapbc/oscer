# frozen_string_literal: true

require "rails_helper"

RSpec.describe ActivityReportApplicationFormsController, type: :routing do
  describe "routing" do
    it "routes to #new" do
      expect(get: "/activity_report_application_forms/new").to route_to("activity_report_application_forms#new")
    end

    it "routes to #show" do
      expect(get: "/activity_report_application_forms/1").to route_to("activity_report_application_forms#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/activity_report_application_forms/1/edit").to route_to("activity_report_application_forms#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/activity_report_application_forms").to route_to("activity_report_application_forms#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/activity_report_application_forms/1").to route_to("activity_report_application_forms#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/activity_report_application_forms/1").to route_to("activity_report_application_forms#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/activity_report_application_forms/1").to route_to("activity_report_application_forms#destroy", id: "1")
    end
  end
end
