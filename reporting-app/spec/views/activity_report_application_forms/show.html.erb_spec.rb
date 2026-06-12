# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "activity_report_application_forms/show", type: :view do
  let(:activity_report_application_form) { create(:activity_report_application_form) }

  before do
    assign(:activity_report_application_form, activity_report_application_form)
    assign(:monthly_statistics, {})

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

  context "when the form has been submitted (not editable)" do
    before { stub_pundit_for(activity_report_application_form, edit?: false) }

    it "shows the 'being reviewed' message when this form's flow_status is submitted" do
      allow(activity_report_application_form).to receive(:flow_status).and_return("submitted")

      render
      expect(rendered).to have_selector("p", text: I18n.t("activity_report_application_forms.shared.status_messages.submitted"))
    end

    it "shows 'being reviewed' for a resubmitted form even when the case was previously denied" do
      certification_case = create(:certification_case)
      certification_case.activity_report_approval_status = "denied"
      assign(:certification_case, certification_case)
      allow(activity_report_application_form).to receive(:flow_status).and_return("submitted")

      render
      expect(rendered).to have_selector("p", text: I18n.t("activity_report_application_forms.shared.status_messages.submitted"))
      expect(rendered).not_to have_content(I18n.t("activity_report_application_forms.shared.status_messages.denied"))
      expect(rendered).not_to have_selector("p.text-red")
    end

    it "shows the approved message when this form's flow_status is approved" do
      allow(activity_report_application_form).to receive(:flow_status).and_return("approved")

      render
      expect(rendered).to have_selector("p.text-green", text: I18n.t("activity_report_application_forms.shared.status_messages.approved"))
    end

    it "shows the denied message when this form's flow_status is denied" do
      allow(activity_report_application_form).to receive(:flow_status).and_return("denied")

      render
      expect(rendered).to have_selector("p.text-red", text: I18n.t("activity_report_application_forms.shared.status_messages.denied"))
    end
  end
end
