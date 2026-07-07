# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExternalExceptionsLoader, type: :service do
  # write_yaml comes from spec/support/yaml_config_helpers.rb.

  it "aliases ConfigurationError to the shared ConfigLoading::ConfigurationError" do
    # The alias is load-bearing: it keeps ExternalExceptionsLoader::ConfigurationError
    # valid for rescues/specs and makes unqualified `raise ConfigurationError`
    # in transform resolve to the shared class. Pin the object identity explicitly.
    expect(described_class::ConfigurationError).to equal(ConfigLoading::ConfigurationError)
  end

  describe ".safe_load_optional" do
    context "when the file does not exist" do
      it "returns an empty hash without raising" do
        missing_path = "/tmp/definitely_not_a_real_override_#{SecureRandom.hex}.yml"
        result = nil
        expect {
          result = described_class.safe_load_optional(missing_path)
        }.not_to raise_error
        expect(result).to eq({})
      end
    end

    context "when the file is empty (parses to nil)" do
      let(:empty_file) { write_yaml("") }

      after { empty_file.unlink }

      it "returns an empty hash without raising" do
        expect(described_class.safe_load_optional(empty_file.path)).to eq({})
      end
    end

    context "when the file contains only comments (parses to nil)" do
      let(:comments_only_file) { write_yaml("# just a comment\n# another comment\n") }

      after { comments_only_file.unlink }

      it "returns an empty hash without raising" do
        expect(described_class.safe_load_optional(comments_only_file.path)).to eq({})
      end
    end

    context "when the file contains a literal empty hash" do
      let(:empty_hash_file) { write_yaml("{}\n") }

      after { empty_hash_file.unlink }

      it "returns an empty hash" do
        expect(described_class.safe_load_optional(empty_hash_file.path)).to eq({})
      end
    end

    context "when the file contains a valid override hash" do
      let(:override_file) do
        write_yaml(<<~YAML)
          high_unemployment_county:
            enabled: false
          disaster_evacuation:
            enabled: true
        YAML
      end

      after { override_file.unlink }

      it "returns the parsed hash with string keys" do
        result = described_class.safe_load_optional(override_file.path)
        expect(result).to eq(
          "high_unemployment_county" => { "enabled" => false },
          "disaster_evacuation" => { "enabled" => true }
        )
      end
    end

    context "when the YAML contains a disallowed Ruby tag" do
      let(:disallowed_file) { write_yaml("high_unemployment_county: !ruby/symbol enabled") }

      after { disallowed_file.unlink }

      it "raises ConfigurationError with 'Invalid YAML'" do
        expect {
          described_class.safe_load_optional(disallowed_file.path)
        }.to raise_error(ExternalExceptionsLoader::ConfigurationError, /Invalid YAML/)
      end
    end

    context "when the YAML is malformed" do
      let(:malformed_file) { write_yaml("high_unemployment_county: :\n  bad indent: [unclosed") }

      after { malformed_file.unlink }

      it "raises ConfigurationError with 'Invalid YAML'" do
        expect {
          described_class.safe_load_optional(malformed_file.path)
        }.to raise_error(ExternalExceptionsLoader::ConfigurationError, /Invalid YAML/)
      end
    end

    context "when the YAML has a non-Hash top level" do
      let(:list_file) { write_yaml("- just\n- a\n- list\n") }

      after { list_file.unlink }

      it "raises ConfigurationError matching 'Expected a Hash at top level'" do
        expect {
          described_class.safe_load_optional(list_file.path)
        }.to raise_error(ExternalExceptionsLoader::ConfigurationError, /Expected a Hash at top level/)
      end
    end
  end

  describe ".merge_with_defaults" do
    context "with an empty override hash" do
      it "returns DEFAULTS verbatim" do
        expect(described_class.merge_with_defaults({})).to eq(ExternalExceptionsLoader::DEFAULTS)
      end
    end

    context "with an override that disables a default" do
      it "deep-merges; override values win on shared keys" do
        result = described_class.merge_with_defaults("high_unemployment_county" => { "enabled" => false })
        expect(result["high_unemployment_county"]["enabled"]).to be false
        expect(result["inpatient_medical_care"]["enabled"]).to be true
      end

      it "preserves all other defaults intact" do
        result = described_class.merge_with_defaults("high_unemployment_county" => { "enabled" => false })
        expect(result.size).to eq(ExternalExceptionsLoader::DEFAULTS.size)
        %w[inpatient_medical_care declared_emergency_county medical_travel].each do |id|
          expect(result[id]["enabled"]).to be true
        end
      end
    end

    context "with an override that adds a new entry" do
      it "produces all defaults plus the new entry" do
        result = described_class.merge_with_defaults("disaster_evacuation" => { "enabled" => true })
        expect(result.size).to eq(ExternalExceptionsLoader::DEFAULTS.size + 1)
        expect(result["disaster_evacuation"]["enabled"]).to be true
      end
    end
  end

  describe ".transform" do
    context "with a well-formed hash-of-hashes (happy path)" do
      let(:merged) do
        {
          "inpatient_medical_care" => { "enabled" => true, "display_order" => 1 },
          "medical_travel" => { "enabled" => true }
        }
      end

      it "returns an array of entries with id as Symbol and enabled as Boolean" do
        result = described_class.transform(merged)
        expect(result).to be_an(Array)
        expect(result.first[:id]).to be_a(Symbol)
        expect(result.first[:enabled]).to be(true).or be(false)
      end

      # Regression guard for the `attrs.symbolize_keys.merge(id: id.to_sym)`
      # pass-through (vs. hardcoded `{id:, enabled:}` narrowing). If a future
      # refactor narrows the merge to only well-known keys, this fails.
      it "passes through extra entry attributes unchanged" do
        result = described_class.transform(merged)
        entry = result.find { |e| e[:id] == :inpatient_medical_care }
        expect(entry[:display_order]).to eq(1)
      end
    end

    context "when an entry value is not a Hash" do
      it "raises ConfigurationError mentioning the offending id" do
        merged = { "inpatient_medical_care" => true }
        expect {
          described_class.transform(merged)
        }.to raise_error(ExternalExceptionsLoader::ConfigurationError, /inpatient_medical_care/)
      end
    end

    context "when an entry is missing the enabled field" do
      it "raises ConfigurationError mentioning the offending id" do
        merged = { "inpatient_medical_care" => {} }
        expect {
          described_class.transform(merged)
        }.to raise_error(ExternalExceptionsLoader::ConfigurationError, /inpatient_medical_care/)
      end
    end
  end

  describe "round-trip" do
    # Locks Hash#key? semantics: enabled: false must round-trip as Boolean false
    # rather than triggering the missing-field error path.
    context "when enabled is explicitly set to false" do
      let(:override_file) do
        write_yaml(<<~YAML)
          medical_travel:
            enabled: false
        YAML
      end

      after { override_file.unlink }

      it "preserves enabled: false as Boolean false through load + merge + transform" do
        overrides = described_class.safe_load_optional(override_file.path)
        merged = described_class.merge_with_defaults(overrides)
        result = described_class.transform(merged)
        entry = result.find { |e| e[:id] == :medical_travel }
        expect(entry[:enabled]).to be false
      end
    end
  end

  describe "integration" do
    it "module-direct against real override path returns the 4 OSCER defaults, all enabled" do
      override_path = Rails.root.join("config/custom/external_exceptions.yml")
      overrides = described_class.safe_load_optional(override_path)
      merged = described_class.merge_with_defaults(overrides)
      result = described_class.transform(merged)

      expected_ids = %i[
        inpatient_medical_care
        declared_emergency_county
        high_unemployment_county
        medical_travel
      ]
      expect(result.map { |e| e[:id] }).to match_array(expected_ids)
      expect(result.map { |e| e[:enabled] }).to all(be true)
    end

    # Initializer-wired boot test: catches initializer-wiring regressions
    # (e.g., missing explicit require, name typo on Rails.application.config)
    # that module-direct tests can't see.
    it "Rails.application.config.external_exceptions is wired by the initializer on boot" do
      types = Rails.application.config.external_exceptions
      expect(types).to be_an(Array)
      expected_ids = %i[
        inpatient_medical_care
        declared_emergency_county
        high_unemployment_county
        medical_travel
      ]
      expect(types.map { |e| e[:id] }).to match_array(expected_ids)
      expect(types.map { |e| e[:enabled] }).to all(be true)
    end
  end
end
