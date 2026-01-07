# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "exemption_screener/index", type: :view do
  let(:user) { create(:user) }
  let(:certification) { create(:certification, :connected_to_email, email: user.email) }
  let(:certification_case) { create(:certification_case, certification: certification) }
  let(:first_exemption_type) { Exemption.first_type }

  before do
    assign(:certification_case, certification_case)
    assign(:certification, certification)
    assign(:first_exemption_type, first_exemption_type)
  end

  it "renders links to dashboard and first exemption question" do
    render

    expect(rendered).to have_link(href: dashboard_path)
    expect(rendered).to have_link(
      href: exemption_screener_question_path(
        exemption_type: first_exemption_type,
        certification_case_id: certification_case.id
      )
    )
  end

  it "renders the heading and description" do
    render

    expect(rendered).to have_css("h1")
    expect(rendered).to have_css("p.font-serif-md")
  end
end
