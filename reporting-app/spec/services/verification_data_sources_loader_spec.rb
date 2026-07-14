# frozen_string_literal: true

require "rails_helper"

RSpec.describe VerificationDataSourcesLoader, type: :service do
  # write_yaml comes from spec/support/yaml_config_helpers.rb.

  # A well-formed entry attrs hash (string keys, as YAML parses them). Specs
  # tweak one field at a time to exercise a single validation.
  def source_attrs(overrides = {})
    {
      "enabled" => true,
      "adapter_class" => "Verification::Adapters::VaDisabilityRating",
      "checks" => {
        "exclusion" => [ "is_veteran_with_disability" ],
        "exception" => [],
        "ce" => []
      },
      "exception_order" => nil,
      "ce_order" => nil
    }.merge(overrides)
  end

  it "aliases ConfigurationError to the shared ConfigLoading::ConfigurationError" do
    # Same load-bearing alias as the sibling loaders: keeps
    # VerificationDataSourcesLoader::ConfigurationError valid for rescues/specs and
    # lets unqualified `raise ConfigurationError` resolve to the shared class.
    expect(described_class::ConfigurationError).to equal(ConfigLoading::ConfigurationError)
  end

  describe ".safe_load_optional (via extend ConfigLoading)" do
    # Exhaustive YAML edge-case coverage lives in the shared ConfigLoading spec;
    # here we only confirm the extend is wired.
    it "returns an empty hash for a missing override file without raising" do
      missing_path = "/tmp/no_such_verification_data_sources_#{SecureRandom.hex}.yml"
      expect(described_class.safe_load_optional(missing_path)).to eq({})
    end

    context "when the file contains a valid override hash" do
      let(:override_file) do
        write_yaml(<<~YAML)
          va_disability_rating:
            enabled: false
        YAML
      end

      after { override_file.unlink }

      it "returns the parsed hash with string keys" do
        expect(described_class.safe_load_optional(override_file.path)).to eq(
          "va_disability_rating" => { "enabled" => false }
        )
      end
    end
  end

  describe ".merge_with_defaults" do
    context "with an empty override hash" do
      it "returns DEFAULTS verbatim" do
        expect(described_class.merge_with_defaults({})).to eq(described_class::DEFAULTS)
      end
    end

    context "with an override that toggles a shipped source off" do
      it "deep-merges: the override wins and unrelated keys are preserved" do
        result = described_class.merge_with_defaults(
          "va_disability_rating" => { "enabled" => false }
        )
        entry = result["va_disability_rating"]
        expect(entry["enabled"]).to be(false)
        expect(entry["adapter_class"]).to eq("Verification::Adapters::VaDisabilityRating")
        expect(entry["checks"]["exclusion"]).to eq([ "is_veteran_with_disability" ])
      end
    end

    context "with an override that adds a new source" do
      it "produces all defaults plus the new entry" do
        result = described_class.merge_with_defaults(
          "county_feed" => { "enabled" => true, "adapter_class" => "Foo" }
        )
        expect(result.size).to eq(described_class::DEFAULTS.size + 1)
        expect(result["county_feed"]).to eq("enabled" => true, "adapter_class" => "Foo")
      end
    end
  end

  describe ".transform (structural validation)" do
    it "returns entries with symbolized id, categories, and check ids" do
      result = described_class.transform("va_disability_rating" => source_attrs)
      entry = result.first
      expect(entry[:id]).to eq(:va_disability_rating)
      expect(entry[:enabled]).to be(true)
      expect(entry[:adapter_class]).to eq("Verification::Adapters::VaDisabilityRating")
      expect(entry[:checks]).to eq(exclusion: [ :is_veteran_with_disability ], exception: [], ce: [])
      expect(entry[:exception_order]).to be_nil
      expect(entry[:ce_order]).to be_nil
    end

    it "defaults omitted check categories to empty arrays" do
      result = described_class.transform(
        "src" => source_attrs("checks" => { "exclusion" => [ "is_veteran_with_disability" ] })
      )
      expect(result.first[:checks]).to eq(exclusion: [ :is_veteran_with_disability ], exception: [], ce: [])
    end

    it "raises naming the id when an entry value is not a Hash" do
      expect {
        described_class.transform("va_disability_rating" => true)
      }.to raise_error(described_class::ConfigurationError, /va_disability_rating/)
    end

    it "raises naming the id when 'enabled' is missing" do
      expect {
        described_class.transform("src" => source_attrs.except("enabled"))
      }.to raise_error(described_class::ConfigurationError, /src.*enabled/)
    end

    it "raises when 'enabled' is not a boolean" do
      expect {
        described_class.transform("src" => source_attrs("enabled" => "yes"))
      }.to raise_error(described_class::ConfigurationError, /enabled/)
    end

    it "raises when 'adapter_class' is missing" do
      expect {
        described_class.transform("src" => source_attrs.except("adapter_class"))
      }.to raise_error(described_class::ConfigurationError, /adapter_class/)
    end

    it "raises when 'adapter_class' is blank" do
      expect {
        described_class.transform("src" => source_attrs("adapter_class" => ""))
      }.to raise_error(described_class::ConfigurationError, /adapter_class/)
    end

    it "raises when 'checks' is not a Hash" do
      expect {
        described_class.transform("src" => source_attrs("checks" => [ "exclusion" ]))
      }.to raise_error(described_class::ConfigurationError, /checks/)
    end

    it "raises naming an unknown check category" do
      expect {
        described_class.transform("src" => source_attrs("checks" => { "bogus" => [] }))
      }.to raise_error(described_class::ConfigurationError, /unknown check category.*bogus/)
    end

    it "raises when a category's value is not an Array" do
      expect {
        described_class.transform("src" => source_attrs("checks" => { "exclusion" => "x" }))
      }.to raise_error(described_class::ConfigurationError, /checks\.exclusion.*Array/)
    end

    it "raises when a check id is not a String" do
      expect {
        described_class.transform("src" => source_attrs("checks" => { "exclusion" => [ 42 ] }))
      }.to raise_error(described_class::ConfigurationError, /checks\.exclusion.*non-String/)
    end

    it "raises when an order field is not an Integer" do
      expect {
        described_class.transform("src" => source_attrs("exception_order" => "10"))
      }.to raise_error(described_class::ConfigurationError, /exception_order.*Integer/)
    end

    it "rejects an 'exclusion_order' key (owned by Exclusion.priority_order)" do
      expect {
        described_class.transform("src" => source_attrs("exclusion_order" => 10))
      }.to raise_error(described_class::ConfigurationError, /exclusion_order.*not configurable/)
    end

    it "raises when two sources share an exception_order" do
      merged = {
        "a" => source_attrs("exception_order" => 10),
        "b" => source_attrs("exception_order" => 10)
      }
      expect {
        described_class.transform(merged)
      }.to raise_error(described_class::ConfigurationError, /duplicate exception_order/)
    end

    it "raises when two sources share a ce_order" do
      merged = {
        "a" => source_attrs("ce_order" => 5),
        "b" => source_attrs("ce_order" => 5)
      }
      expect {
        described_class.transform(merged)
      }.to raise_error(described_class::ConfigurationError, /duplicate ce_order/)
    end

    it "allows multiple sources with distinct (and nil) order values" do
      merged = {
        "a" => source_attrs("exception_order" => 10),
        "b" => source_attrs("exception_order" => 20),
        "c" => source_attrs("exception_order" => nil)
      }
      expect { described_class.transform(merged) }.not_to raise_error
    end
  end

  describe ".validate_registry! (application-constant-dependent validation)" do
    it "passes for the real VA adapter declaring a real exclusion id" do
      entries = described_class.transform("va_disability_rating" => source_attrs)
      expect { described_class.validate_registry!(entries) }.not_to raise_error
    end

    it "accepts any adapter_class that subclasses Verification::DataSource" do
      stub_const("SpecFixtureSource", Class.new(Verification::DataSource))
      entries = described_class.transform(
        "src" => source_attrs("adapter_class" => "SpecFixtureSource", "checks" => {})
      )
      expect { described_class.validate_registry!(entries) }.not_to raise_error
    end

    it "raises when adapter_class does not constantize" do
      entries = described_class.transform(
        "src" => source_attrs("adapter_class" => "Verification::Adapters::TotallyMissing", "checks" => {})
      )
      expect {
        described_class.validate_registry!(entries)
      }.to raise_error(described_class::ConfigurationError, /does not constantize/)
    end

    it "raises when adapter_class is not a Verification::DataSource subclass" do
      entries = described_class.transform(
        "src" => source_attrs("adapter_class" => "String", "checks" => {})
      )
      expect {
        described_class.validate_registry!(entries)
      }.to raise_error(described_class::ConfigurationError, /must be a Verification::DataSource subclass/)
    end

    it "raises when an exclusion check id is not in Exclusion.valid_values" do
      entries = described_class.transform(
        "src" => source_attrs("checks" => { "exclusion" => [ "not_a_real_exclusion" ] })
      )
      expect {
        described_class.validate_registry!(entries)
      }.to raise_error(described_class::ConfigurationError, /checks\.exclusion.*not_a_real_exclusion/)
    end

    it "raises when an exception check id is not in the ExternalException registry" do
      entries = described_class.transform(
        "src" => source_attrs("checks" => { "exception" => [ "not_a_real_exception" ] })
      )
      expect {
        described_class.validate_registry!(entries)
      }.to raise_error(described_class::ConfigurationError, /checks\.exception.*not_a_real_exception/)
    end

    it "accepts a real exception check id from the ExternalException registry" do
      entries = described_class.transform(
        "src" => source_attrs("checks" => { "exception" => [ ExternalException.all.first[:id].to_s ] })
      )
      expect { described_class.validate_registry!(entries) }.not_to raise_error
    end

    it "does not membership-check CE ids (no CE registry yet)" do
      entries = described_class.transform(
        "src" => source_attrs("checks" => { "ce" => [ "some_future_ce_id" ] })
      )
      expect { described_class.validate_registry!(entries) }.not_to raise_error
    end

    it "validates even sources that are disabled" do
      entries = described_class.transform(
        "src" => source_attrs("enabled" => false, "adapter_class" => "String", "checks" => {})
      )
      expect {
        described_class.validate_registry!(entries)
      }.to raise_error(described_class::ConfigurationError)
    end
  end

  describe "full pipeline against the shipped defaults + override file" do
    it "loads, merges, transforms, and passes registry validation" do
      override_path = Rails.root.join("config/custom/verification_data_sources.yml")
      overrides = described_class.safe_load_optional(override_path)
      merged = described_class.merge_with_defaults(overrides)
      entries = described_class.transform(merged)

      expect(entries.map { |e| e[:id] }).to include(:va_disability_rating)
      expect { described_class.validate_registry!(entries) }.not_to raise_error
    end
  end

  describe "initializer wiring" do
    it "sets Rails.application.config.verification_data_sources on boot" do
      sources = Rails.application.config.verification_data_sources
      expect(sources).to be_an(Array)

      va = sources.find { |s| s[:id] == :va_disability_rating }
      expect(va[:adapter_class]).to eq("Verification::Adapters::VaDisabilityRating")
      expect(va[:checks][:exclusion]).to eq([ :is_veteran_with_disability ])
    end
  end
end
