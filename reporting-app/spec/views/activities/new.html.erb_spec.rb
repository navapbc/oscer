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

    assert_select "form[action=?][method=?]", activity_report_application_form_activities_path(activity_report_application_form), "post" do
      assert_select "[name=?]", "activity[hours]"
      assert_select "[name=?]", "activity[name]"
      assert_select "[name=?]", "activity[month]"
    end
  end
end
