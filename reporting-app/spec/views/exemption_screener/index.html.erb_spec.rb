# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "exemption_screener/index", type: :view do
  let(:user) { create(:user) }
  let(:certification) { create(:certification, :connected_to_email, email: user.email) }
  let(:certification_case) { create(:certification_case, certification: certification) }

  before do
    assign(:certification_case, certification_case)
    assign(:certification, certification)
  end

  it "renders links" do
    render

    expect(rendered).to have_link(href: new_exemption_application_form_path(certification_case_id: certification_case.id))
    expect(rendered).to have_link(href: new_activity_report_application_form_path(certification_case_id: certification_case.id))
  end
end
