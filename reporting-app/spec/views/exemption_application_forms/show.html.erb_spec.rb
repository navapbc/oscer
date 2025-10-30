# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "exemption_application_forms/show", type: :view do
  let(:exemption_application_form) { create(:exemption_application_form, exemption_type: "incarceration") }

  before do
    assign(:exemption_application_form, exemption_application_form)

    stub_pundit_for(exemption_application_form, edit?: true)
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(exemption_application_form.exemption_type.capitalize)
  end
end
