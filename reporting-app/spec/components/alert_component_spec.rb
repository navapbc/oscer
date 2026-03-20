# frozen_string_literal: true

require "rails_helper"

RSpec.describe AlertComponent, type: :component do
  describe "types" do
    it "renders each type with matching modifier class" do
      AlertComponent::TYPES.each do |alert_type|
        render_inline(described_class.new(type: alert_type, message: "x"))
        expect(page).to have_css(".usa-alert.usa-alert--#{alert_type}")
      end
    end

    it "raises for invalid type" do
      expect do
        described_class.new(type: "bogus", message: "x")
      end.to raise_error(ArgumentError, /Invalid alert type/)
    end
  end

  describe "ARIA role" do
    it "sets role=alert only for error" do
      render_inline(described_class.new(type: "error", message: "e"))
      expect(page).to have_css('.usa-alert[role="alert"]')
    end

    it "omits role for non-error types" do
      %w[info success warning].each do |alert_type|
        render_inline(described_class.new(type: alert_type, message: "m"))
        expect(page).to have_css(".usa-alert.usa-alert--#{alert_type}")
        expect(page).to have_no_css('.usa-alert[role]')
      end
    end
  end

  describe "simple mode" do
    it "renders message in usa-alert__text" do
      render_inline(described_class.new(type: "success", message: "Saved"))
      expect(page).to have_css("p.usa-alert__text", text: "Saved")
    end

    it "renders optional heading at the given level" do
      render_inline(described_class.new(type: "info", heading: "Title", message: "Body", heading_level: 4))
      expect(page).to have_css("h4.usa-alert__heading", text: "Title")
      expect(page).to have_css("p.usa-alert__text", text: "Body")
    end
  end

  describe "block mode (body slot)" do
    it "renders slot content instead of message" do
      render_inline(described_class.new(type: "error", heading: "Problems")) do |c|
        c.with_body { "<ul class='usa-list'><li>a</li></ul>".html_safe }
      end
      expect(page).to have_css("h2.usa-alert__heading", text: "Problems")
      expect(page).to have_css("ul.usa-list li", text: "a")
      expect(page).to have_no_css("p.usa-alert__text")
    end

    it "renders heading before body when both heading and slot are used (e.g. warning + actions)" do
      render_inline(described_class.new(type: "warning", heading: "Notice", heading_level: 3)) do |c|
        c.with_body { "<p class='usa-alert__text'>Details</p>".html_safe }
      end
      expect(page).to have_css("h3.usa-alert__heading", text: "Notice")
      expect(page).to have_css("p.usa-alert__text", text: "Details")
      expect(page).to have_no_css('.usa-alert[role]')
    end
  end

  describe "extra attributes" do
    it "merges classes onto the root" do
      render_inline(described_class.new(type: "info", message: "m", classes: "margin-top-4 usa-alert--slim"))
      expect(page).to have_css(".usa-alert.margin-top-4.usa-alert--slim")
    end

    it "passes style to the root element" do
      render_inline(described_class.new(type: "info", message: "m", style: "padding: unset;"))
      expect(page).to have_css('.usa-alert[style="padding: unset;"]')
    end
  end

  describe "heading_level validation" do
    it "rejects invalid heading levels" do
      expect do
        described_class.new(type: "info", message: "m", heading_level: 7)
      end.to raise_error(ArgumentError, /heading_level/)
    end
  end
end
