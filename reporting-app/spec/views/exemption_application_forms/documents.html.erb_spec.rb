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

  describe "Stimulus + disabled-state render contract" do
    before { render }

    it "wraps the upload area in the document-upload Stimulus controller" do
      assert_select "[data-controller~='document-upload']"
    end

    it "marks the file input as the fileInput target and wires the change action" do
      assert_select "input[type='file'][data-document-upload-target='fileInput']" \
                    "[data-action*='change->document-upload#fileSelectionChanged']"
    end

    it "marks the Upload submit as the uploadButton target" do
      # NOTE: the submit is NOT server-rendered `disabled`; the Stimulus
      # controller disables it in connect() so the no-JS fallback keeps the
      # button functional.
      assert_select "input[type='submit'][data-document-upload-target='uploadButton']:not([disabled])"
    end

    it "marks the Continue link as the continueLink target, wires the click action, and renders aria-disabled=false" do
      assert_select "a[data-document-upload-target='continueLink']" \
                    "[data-action*='click->document-upload#blockIfDisabled']" \
                    "[aria-disabled='false']"
    end

    it "does not apply the is-disabled-link class on initial render" do
      assert_select "a[data-document-upload-target='continueLink']:not(.is-disabled-link)"
    end

    it "renders the Continue link as the primary (non-outline) button" do
      assert_select "a[data-document-upload-target='continueLink']" do |elements|
        expect(elements.first["class"]).to include("usa-button")
        expect(elements.first["class"]).not_to include("usa-button--outline")
      end
    end
  end
end
