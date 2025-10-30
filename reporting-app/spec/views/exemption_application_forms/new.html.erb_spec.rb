# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "exemption_application_forms/new", type: :view do
  before do
    assign(:exemption_application_form, ExemptionApplicationForm.new())
  end

  it "renders new exemption_application_form form" do
    render

    assert_select "form[action=?][method=?]", exemption_application_forms_path, "post" do
    end
  end
end
