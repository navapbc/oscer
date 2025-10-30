# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "activity_report_application_forms/new", type: :view do
  let(:certification_case) { create(:certification_case) }

  before do
    assign(:certification_case, certification_case)
    stub_pundit_for(ActivityReportApplicationForm, new?: true)
  end

  it "renders 'Before you start' view" do
    render

    expect(rendered).to have_selector("h1", text: "Before you start")
  end

  it "renders time to complete text" do
    render
    expect(rendered).to have_selector("dt strong", text: "Estimated time to complete:")
    expect(rendered).to have_selector("dd", text: "Less than 30 minutes")
  end

  it "renders materials list" do
    render
    expect(rendered).to have_selector("p", text: "Before you begin, please have the following ready:")
    expect(rendered).to have_selector(
      "ul li",
      text: "Details about your work, educational programs, community service, or work programs"
    )
    expect(rendered).to have_selector(
      "ul li",
      text: "Supporting documentation"
    )
    expect(rendered).to have_selector("p", text: "You can save your progress and return anytime")
  end

  it "renders 'Start' button" do
    render
    expect(rendered).to have_selector("input[type='submit'][value='Start']")
  end
end
