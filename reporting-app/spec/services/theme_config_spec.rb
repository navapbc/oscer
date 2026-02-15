# frozen_string_literal: true

require "rails_helper"

RSpec.describe ThemeConfig, type: :service do
  after do
    described_class.reset!
  end

  describe ".current" do
    context "when OSCER_THEME is not set" do
      before do
        allow(ENV).to receive(:fetch).with("OSCER_THEME", "default").and_return("default")
      end

      it "returns the default theme" do
        theme = described_class.current
        expect(theme.theme_key).to eq("default")
      end

      it "returns a cached instance" do
        first_call = described_class.current
        second_call = described_class.current
        expect(first_call).to be(second_call)
      end
    end

    context "when OSCER_THEME is set to valid theme" do
      before do
        allow(ENV).to receive(:fetch).with("OSCER_THEME", "default").and_return("nava_state")
      end

      it "returns the specified theme" do
        theme = described_class.current
        expect(theme.theme_key).to eq("nava_state")
      end

      it "loads the correct theme configuration" do
        theme = described_class.current
        expect(theme.name).to eq("State of Nava PBC")
        expect(theme.primary_color).to eq("#1a3d5c")
      end
    end

    context "when OSCER_THEME references unknown theme" do
      before do
        allow(ENV).to receive(:fetch).with("OSCER_THEME", "default").and_return("nonexistent_theme")
        allow(Rails.logger).to receive(:warn)
      end

      it "falls back to default theme" do
        theme = described_class.current
        expect(theme.theme_key).to eq("default")
      end

      it "logs a warning" do
        described_class.current
        expect(Rails.logger).to have_received(:warn).with(/Unknown theme 'nonexistent_theme', falling back to default/)
      end
    end

    context "when config file is missing" do
      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(ThemeConfig::CONFIG_PATH).and_return(false)
      end

      it "raises ConfigurationError" do
        expect { described_class.current }
          .to raise_error(ThemeConfig::ConfigurationError, /Theme configuration not found/)
      end
    end

    context "when config file has invalid YAML" do
      let(:invalid_yaml_path) { Rails.root.join("tmp/invalid_themes.yml") }

      before do
        FileUtils.mkdir_p(Rails.root.join("tmp"))
        File.write(invalid_yaml_path, "invalid: yaml: syntax: [")
        stub_const("ThemeConfig::CONFIG_PATH", invalid_yaml_path)
      end

      after do
        File.delete(invalid_yaml_path) if File.exist?(invalid_yaml_path)
      end

      it "raises ConfigurationError" do
        expect { described_class.current }
          .to raise_error(ThemeConfig::ConfigurationError, /Invalid YAML/)
      end
    end
  end

  describe ".reset!" do
    before do
      allow(ENV).to receive(:fetch).with("OSCER_THEME", "default").and_return("default")
    end

    it "clears the cached instance" do
      first_instance = described_class.current
      described_class.reset!
      second_instance = described_class.current
      expect(first_instance).not_to be(second_instance)
    end
  end

  describe "accessors" do
    let(:theme) do
      described_class.new("nava_state", {
        "name" => "State of Nava PBC",
        "agency_name" => "State of Nava PBC - Department of Health Services",
        "primary_color" => "#1a3d5c",
        "secondary_color" => "#2d5a7b",
        "accent_color" => "#f0c14b",
        "background_color" => "#f5f5f5",
        "text_color" => "#1a1a1a",
        "logo" => "nava-state-logo.svg",
        "favicon" => "nava-state-favicon.png",
        "contact_email" => "help@dhs.nava.gov",
        "banner_text" => "Official State of Nava PBC Government Website",
        "footer_links" => [
          { "label" => "Privacy", "url" => "https://nava.gov/privacy" }
        ]
      })
    end

    it "returns theme_key" do
      expect(theme.theme_key).to eq("nava_state")
    end

    it "returns name" do
      expect(theme.name).to eq("State of Nava PBC")
    end

    it "returns agency_name" do
      expect(theme.agency_name).to eq("State of Nava PBC - Department of Health Services")
    end

    it "returns primary_color" do
      expect(theme.primary_color).to eq("#1a3d5c")
    end

    it "returns secondary_color" do
      expect(theme.secondary_color).to eq("#2d5a7b")
    end

    it "returns accent_color" do
      expect(theme.accent_color).to eq("#f0c14b")
    end

    it "returns background_color" do
      expect(theme.background_color).to eq("#f5f5f5")
    end

    it "returns text_color" do
      expect(theme.text_color).to eq("#1a1a1a")
    end

    it "returns logo" do
      expect(theme.logo).to eq("nava-state-logo.svg")
    end

    it "returns favicon" do
      expect(theme.favicon).to eq("nava-state-favicon.png")
    end

    it "returns contact_email" do
      expect(theme.contact_email).to eq("help@dhs.nava.gov")
    end

    it "returns banner_text" do
      expect(theme.banner_text).to eq("Official State of Nava PBC Government Website")
    end

    it "returns footer_links with symbolized keys" do
      links = theme.footer_links
      expect(links).to be_an(Array)
      expect(links.first[:label]).to eq("Privacy")
      expect(links.first[:url]).to eq("https://nava.gov/privacy")
    end
  end

  describe "#banner?" do
    context "when banner_text is present" do
      let(:theme) do
        described_class.new("test", { "banner_text" => "Some banner" })
      end

      it "returns true" do
        expect(theme.banner?).to be true
      end
    end

    context "when banner_text is nil" do
      let(:theme) do
        described_class.new("test", { "banner_text" => nil })
      end

      it "returns false" do
        expect(theme.banner?).to be false
      end
    end

    context "when banner_text is empty string" do
      let(:theme) do
        described_class.new("test", { "banner_text" => "" })
      end

      it "returns false" do
        expect(theme.banner?).to be false
      end
    end
  end

  describe "#default?" do
    context "when theme is default" do
      let(:theme) { described_class.new("default", {}) }

      it "returns true" do
        expect(theme.default?).to be true
      end
    end

    context "when theme is not default" do
      let(:theme) { described_class.new("nava_state", {}) }

      it "returns false" do
        expect(theme.default?).to be false
      end
    end
  end

  describe "#footer_links" do
    context "when footer_links is present" do
      let(:theme) do
        described_class.new("test", {
          "footer_links" => [
            { "label" => "Link 1", "url" => "/link1" },
            { "label" => "Link 2", "url" => "/link2" }
          ]
        })
      end

      it "returns the footer links" do
        expect(theme.footer_links.length).to eq(2)
      end
    end

    context "when footer_links is nil" do
      let(:theme) { described_class.new("test", {}) }

      it "returns empty array" do
        expect(theme.footer_links).to eq([])
      end
    end
  end

  describe "configuration immutability" do
    let(:theme) do
      described_class.new("test", { "name" => "Test Theme" })
    end

    it "freezes the configuration" do
      expect { theme.instance_variable_get(:@config)[:name] = "Modified" }
        .to raise_error(FrozenError)
    end
  end

  describe "integration with config file" do
    before do
      allow(ENV).to receive(:fetch).with("OSCER_THEME", "default").and_return("default")
    end

    it "loads default theme from themes.yml" do
      theme = described_class.current

      expect(theme.name).to eq("OSCER")
      expect(theme.agency_name).to eq("OSCER Platform")
      expect(theme.primary_color).to eq("#005ea2")
    end

    context "when loading nava_state theme" do
      before do
        allow(ENV).to receive(:fetch).with("OSCER_THEME", "default").and_return("nava_state")
      end

      it "loads nava_state theme from themes.yml" do
        theme = described_class.current

        expect(theme.name).to eq("State of Nava PBC")
        expect(theme.primary_color).to eq("#1a3d5c")
        expect(theme.secondary_color).to eq("#2d5a7b")
        expect(theme.accent_color).to eq("#f0c14b")
        expect(theme.banner_text).to eq("Official State of Nava PBC Government Website")
        expect(theme.banner?).to be true
      end
    end
  end
end
