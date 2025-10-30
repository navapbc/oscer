# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "activities/show", type: :view do
  let(:activity_report_application_form) { create(:activity_report_application_form, :with_activities) }
  let(:activity) { activity_report_application_form.activities.first }

  before do
    assign(:activity_report_application_form, activity_report_application_form)
    assign(:activity, activity)
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(ERB::Util.html_escape(activity.name))
    expect(rendered).to match(activity.hours.to_s)
    expect(rendered).to match(activity.month.strftime("%B %Y"))
  end
end
