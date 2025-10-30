# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "exemption_application_forms/exemption_type", type: :view do
  let(:exemption_application_form) { create(:exemption_application_form) }

  before do
    assign(:exemption_application_form, exemption_application_form)
  end

  it "renders the exemption type selection form" do
    render

    assert_select "form[action=?][method=?]", exemption_application_form_path(exemption_application_form), "post" do
    end
  end
end
