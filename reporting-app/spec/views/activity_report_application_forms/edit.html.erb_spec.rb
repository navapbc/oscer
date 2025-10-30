# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "activity_report_application_forms/edit", type: :view do
  let(:activity_report_application_form) { create(:activity_report_application_form) }
  let(:certification) { create(:certification) }

  before do
    assign(:activity_report_application_form, activity_report_application_form)
    assign(:certification_requirements, certification.certification_requirements)
  end

  it "renders the edit activity_report_application_form form" do
    render

    assert_select "form[action=?][method=?]", activity_report_application_form_path(activity_report_application_form), "post" do
    end
  end
end
