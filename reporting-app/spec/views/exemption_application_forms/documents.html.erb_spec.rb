# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "exemption_application_forms/documents", type: :view do
  before do
    assign(:exemption_application_form, create(:exemption_application_form))
  end

  it "renders exemption_application_form document upload form" do
    render

    assert_select "input[name=?]", "exemption_application_form[supporting_documents][]"
  end
end
