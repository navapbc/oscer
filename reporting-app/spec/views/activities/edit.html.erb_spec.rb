# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "activities/edit", type: :view do
  let(:activity_report_application_form) { create(:activity_report_application_form, :with_activities) }
  let(:activity) { activity_report_application_form.activities.first }

  before do
    assign(:activity_report_application_form, activity_report_application_form)
    assign(:activity, activity)
  end

  it "renders the edit activity form" do
    render

    assert_select "form[action=?][method=?]", activity_report_application_form_activity_path(activity_report_application_form, activity), "post" do
      assert_select "[name=?]", "activity[hours]"
      assert_select "[name=?]", "activity[name]"
      assert_select "[name=?]", "activity[month]"
    end
  end
end
