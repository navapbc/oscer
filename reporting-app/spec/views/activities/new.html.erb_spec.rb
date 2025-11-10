# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "activities/new", type: :view do
  let(:activity_report_application_form) { create(:activity_report_application_form) }

  before do
    assign(:activity_report_application_form, activity_report_application_form)
    render
  end

  it "renders the category selection fieldset" do
    expect(rendered).to have_text('Activity type')
  end

  it "renders category radio buttons" do
    assert_select "input[type=radio][name=?]", "category" do
      assert_select "input[value=?]", "employment"
      assert_select "input[value=?]", "education"
      assert_select "input[value=?]", "community_service"
    end
  end

  it "renders the reporting method selection fieldset" do
    assert_select "input[type=radio][name=?]", "activity_type" do
      assert_select "input[value=?]", "work_activity"
      assert_select "input[value=?]", "income_activity"
    end
  end

  it "renders the continue button" do
    assert_select "input[type=submit]"
  end

  it "renders the form with correct URL and method" do
    assert_select "form[action=?][method=?]", new_activity_new_activity_report_application_form_activity_path(activity_report_application_form), "get"
  end

  it "renders category radio buttons with tile styling" do
    assert_select "form" do
      assert_select "input[type=radio][name=?]", "category", count: 3
      assert_select "input[type=radio][name=?]", "activity_type", count: 2
    end
  end
end
