# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExclusionTypesLoader, type: :service do
  # write_yaml comes from spec/support/yaml_config_helpers.rb.

  # The spec's default priority order (high durability -> low), spaced by 10.
  let(:expected_defaults) do
    {
      is_american_indian_or_alaska_native: 10,
      former_foster_care: 20,
      is_veteran_with_disability: 30,
      medically_frail: 40,
      caretaker: 50,
      tanf_snap_work: 60,
      drug_treatment: 70,
      is_pregnant: 80,
      inmate: 90
    }
  end

  it "aliases ConfigurationError to the shared ConfigLoading::ConfigurationError" do
    # Same load-bearing alias as ExemptionTypesLoader: keeps
    # ExclusionTypesLoader::ConfigurationError valid for rescues/specs and lets
    # unqualified `raise ConfigurationError` in transform resolve to the shared class.
    expect(described_class::ConfigurationError).to equal(ConfigLoading::ConfigurationError)
  end

  describe ".safe_load_optional (via extend ConfigLoading)" do
    # Exhaustive YAML edge-case coverage lives in the shared ConfigLoading spec
    # and ExemptionTypesLoader spec; here we only confirm the extend is wired.
    it "returns an empty hash for a missing override file without raising" do
      missing_path = "/tmp/definitely_not_a_real_exclusion_override_#{SecureRandom.hex}.yml"
      expect(described_class.safe_load_optional(missing_path)).to eq({})
    end

    context "when the file contains a valid override hash" do
      let(:override_file) do
        write_yaml(<<~YAML)
          former_foster_care:
            priority: 55
        YAML
      end

      after { override_file.unlink }

      it "returns the parsed hash with string keys" do
        expect(described_class.safe_load_optional(override_file.path)).to eq(
          "former_foster_care" => { "priority" => 55 }
        )
      end
    end
  end

  describe ".merge_with_defaults" do
    context "with an empty override hash" do
      it "returns DEFAULTS verbatim" do
        expect(described_class.merge_with_defaults({})).to eq(ExclusionTypesLoader::DEFAULTS)
      end
    end

    context "with an override that re-ranks an exclusion into a gap" do
      it "deep-merges; the overridden priority wins and unrelated entries are untouched" do
        # Move former_foster_care (20) into the gap just below caretaker (50).
        result = described_class.merge_with_defaults("former_foster_care" => { "priority" => 55 })
        expect(result["former_foster_care"]["priority"]).to eq(55)
        expect(result["caretaker"]["priority"]).to eq(50)
        expect(result["is_american_indian_or_alaska_native"]["priority"]).to eq(10)
        expect(result.size).to eq(ExclusionTypesLoader::DEFAULTS.size)
      end
    end

    context "with an override that adds a new exclusion" do
      it "produces all defaults plus the new entry" do
        result = described_class.merge_with_defaults("state_specific" => { "priority" => 100 })
        expect(result.size).to eq(ExclusionTypesLoader::DEFAULTS.size + 1)
        expect(result["state_specific"]).to eq("priority" => 100)
      end
    end
  end

  describe ".transform" do
    context "with a well-formed hash-of-hashes (happy path)" do
      let(:merged) do
        {
          "veteran_disability" => { "priority" => 30 },
          "pregnant" => { "priority" => 80 }
        }
      end

      it "returns an array of entries with id as Symbol and priority as Integer" do
        result = described_class.transform(merged)
        expect(result).to be_an(Array)
        entry = result.find { |e| e[:id] == :veteran_disability }
        expect(entry[:id]).to be_a(Symbol)
        expect(entry[:priority]).to eq(30)
      end
    end

    context "when an entry value is not a Hash" do
      it "raises ConfigurationError mentioning the offending id" do
        expect {
          described_class.transform("pregnant" => true)
        }.to raise_error(ExclusionTypesLoader::ConfigurationError, /pregnant/)
      end
    end

    context "when an entry is missing the priority field" do
      it "raises ConfigurationError mentioning the offending id" do
        expect {
          described_class.transform("pregnant" => {})
        }.to raise_error(ExclusionTypesLoader::ConfigurationError, /pregnant/)
      end
    end

    context "when priority is not an Integer" do
      it "raises ConfigurationError mentioning the offending id" do
        expect {
          described_class.transform("pregnant" => { "priority" => "80" })
        }.to raise_error(ExclusionTypesLoader::ConfigurationError, /pregnant/)
      end
    end

    context "when two entries share a priority" do
      it "raises ConfigurationError naming the duplicate priority" do
        merged = {
          "veteran_disability" => { "priority" => 10 },
          "pregnant" => { "priority" => 10 }
        }
        expect {
          described_class.transform(merged)
        }.to raise_error(ExclusionTypesLoader::ConfigurationError, /duplicate priority/)
      end
    end
  end

  describe "full load pipeline" do
    context "when an override re-ranks an exclusion into a gap" do
      let(:override_file) do
        write_yaml(<<~YAML)
          former_foster_care:
            priority: 55
        YAML
      end

      after { override_file.unlink }

      it "carries the override through load + merge + transform" do
        overrides = described_class.safe_load_optional(override_file.path)
        merged = described_class.merge_with_defaults(overrides)
        result = described_class.transform(merged)

        former_foster_care = result.find { |e| e[:id] == :former_foster_care }
        caretaker = result.find { |e| e[:id] == :caretaker }
        expect(former_foster_care[:priority]).to eq(55)
        expect(caretaker[:priority]).to eq(50)
      end
    end
  end

  describe "integration" do
    it "module-direct against the real override path returns the 9 defaults spaced by 10" do
      override_path = Rails.root.join("config/custom/exclusion_types.yml")
      overrides = described_class.safe_load_optional(override_path)
      merged = described_class.merge_with_defaults(overrides)
      result = described_class.transform(merged)

      by_id = result.index_by { |e| e[:id] }
      expect(by_id.keys).to match_array(expected_defaults.keys)
      expected_defaults.each do |id, priority|
        expect(by_id[id][:priority]).to eq(priority)
      end
    end

    it "wires Rails.application.config.exclusion_types on boot via the initializer" do
      types = Rails.application.config.exclusion_types
      expect(types).to be_an(Array)
      expect(types.map { |e| e[:id] }).to match_array(expected_defaults.keys)
    end
  end
end
