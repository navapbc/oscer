# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "activities/documents", type: :view do
  let(:activity_report) { create(:activity_report_application_form, :with_activities) }

  before do
    assign(:activity_report_application_form, activity_report)
    assign(:activity, activity_report.activities.first)
  end

  it "renders activity document upload form" do
    render

    assert_select "input[name=?]", "activity[supporting_documents][]"
  end
end
