# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "activity_report_application_forms/show", type: :view do
  let(:activity_report_application_form) { create(:activity_report_application_form) }

  before do
    assign(:activity_report_application_form, activity_report_application_form)

    stub_pundit_for(activity_report_application_form, edit?: true)
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Complete and submit your activity report/)
  end

  it "renders link to add activity when editable" do
    render
    expect(rendered).to have_link(
      "Add activity",
      href: new_activity_report_application_form_activity_path(
        activity_report_application_form
      )
    )
  end

  it "does not render link to add activity when not editable" do
    stub_pundit_for(activity_report_application_form, edit?: false)

    render
    expect(rendered).not_to have_link("Add activity")
  end
end
