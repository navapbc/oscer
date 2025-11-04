# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "activities/new", type: :view do
  let(:activity_report_application_form) { create(:activity_report_application_form) }

  before do
    assign(:activity_report_application_form, activity_report_application_form)
    assign(:activity, activity_report_application_form.activities.build)
  end

  it "renders new activity form" do
    render

    assert_select "form[action=?][method=?]", new_activity_new_activity_report_application_form_activity_path(activity_report_application_form), "get" do
      assert_select "input[type=radio][name=?]", "activity_type", count: 2
    end
  end
end
