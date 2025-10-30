# frozen_string_literal: true

require "rails_helper"

RSpec.describe ActivitiesController, type: :routing do
  describe "routing" do
    it "routes to #new" do
      expect(get: "/activity_report_application_forms/1/activities/new").to route_to("activities#new", activity_report_application_form_id: "1")
    end

    it "routes to #show" do
      expect(get: "/activity_report_application_forms/1/activities/1").to route_to("activities#show", activity_report_application_form_id: "1", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/activity_report_application_forms/1/activities/1/edit").to route_to("activities#edit", activity_report_application_form_id: "1", id: "1")
    end


    it "routes to #create" do
      expect(post: "/activity_report_application_forms/1/activities").to route_to("activities#create", activity_report_application_form_id: "1")
    end

    it "routes to #update via PUT" do
      expect(put: "/activity_report_application_forms/1/activities/1").to route_to("activities#update", activity_report_application_form_id: "1", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/activity_report_application_forms/1/activities/1").to route_to("activities#update", activity_report_application_form_id: "1", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/activity_report_application_forms/1/activities/1").to route_to("activities#destroy", activity_report_application_form_id: "1", id: "1")
    end
  end
end
