# frozen_string_literal: true

require "rails_helper"
require "tempfile"

RSpec.describe CEConfiguration, type: :service do
  # Helper: write content to a tempfile and return the closed Tempfile.
  # Callers should `.unlink` in an `after` block and use `.path` for paths.
  def write_yaml(content)
    file = Tempfile.new([ "ce_config_test", ".yml" ])
    file.write(content)
    file.close
    file
  end

  let(:base_yaml) do
    <<~YAML
      exemption_types:
        caregiver_disability:
          enabled: true
        caregiver_child:
          enabled: true
        medical_condition:
          enabled: true
        substance_treatment:
          enabled: true
        incarceration:
          enabled: true
        education_and_training:
          enabled: true
        received_medical_care:
          enabled: true
    YAML
  end

  describe ".load_and_merge" do
    # Test #1: "API contract — happy path with absent custom path"
    # Verifies the loader returns the base file's contents verbatim when the
    # custom path simply doesn't exist as a file on disk.
    context "when only the base file exists (happy path, no custom file)" do
      let(:base_file) { write_yaml(base_yaml) }
      let(:missing_custom_path) { "/tmp/definitely_not_a_real_file_#{SecureRandom.hex}.yml" }

      after { base_file.unlink }

      it "returns base verbatim" do
        result = described_class.load_and_merge(base_file.path, missing_custom_path)
        expect(result).to eq(YAML.safe_load(base_yaml))
      end
    end

    context "when base and custom both exist (happy path, deep merge)" do
      let(:base_file) { write_yaml(base_yaml) }
      let(:custom_file) do
        write_yaml(<<~YAML)
          exemption_types:
            medical_condition:
              enabled: false
        YAML
      end

      after do
        base_file.unlink
        custom_file.unlink
      end

      it "deep-merges custom over base; custom values win on shared keys" do
        result = described_class.load_and_merge(base_file.path, custom_file.path)
        expect(result["exemption_types"]["medical_condition"]["enabled"]).to be false
        expect(result["exemption_types"]["caregiver_child"]["enabled"]).to be true
      end
    end

    context "when override disables a default" do
      let(:base_file) { write_yaml(base_yaml) }
      let(:custom_file) do
        write_yaml(<<~YAML)
          exemption_types:
            medical_condition:
              enabled: false
        YAML
      end

      after do
        base_file.unlink
        custom_file.unlink
      end

      it "preserves all other defaults intact while disabling the targeted one" do
        result = described_class.load_and_merge(base_file.path, custom_file.path)
        types = result["exemption_types"]
        expect(types["medical_condition"]["enabled"]).to be false
        expect(types.size).to eq(7)
        %w[caregiver_disability caregiver_child substance_treatment incarceration
           education_and_training received_medical_care].each do |id|
          expect(types[id]["enabled"]).to be true
        end
      end
    end

    context "when override adds a new entry" do
      let(:base_file) { write_yaml(base_yaml) }
      let(:custom_file) do
        write_yaml(<<~YAML)
          exemption_types:
            disaster_evacuation:
              enabled: true
        YAML
      end

      after do
        base_file.unlink
        custom_file.unlink
      end

      it "produces 7 defaults plus the new entry" do
        result = described_class.load_and_merge(base_file.path, custom_file.path)
        expect(result["exemption_types"].size).to eq(8)
        expect(result["exemption_types"]["disaster_evacuation"]["enabled"]).to be true
      end
    end

    context "when the required base file is missing" do
      it "raises ConfigurationError with path-mentioning message" do
        missing_path = "/tmp/definitely_not_a_real_base_#{SecureRandom.hex}.yml"
        expect {
          described_class.load_and_merge(missing_path, "/tmp/whatever.yml")
        }.to raise_error(CEConfiguration::ConfigurationError, /#{Regexp.escape(missing_path)}/)
      end
    end

    # Test #6: "failure-mode-adjacent — optional file genuinely missing is not an error"
    # Distinct from #1 (which is the API-contract happy path). This test
    # frames the same outcome from the failure-handling perspective: a missing
    # optional file must not surface as an error to callers.
    context "when the optional custom file is missing" do
      let(:base_file) { write_yaml(base_yaml) }

      after { base_file.unlink }

      it "succeeds and returns base unchanged" do
        missing_path = "/tmp/definitely_not_a_real_custom_#{SecureRandom.hex}.yml"
        result = nil
        expect {
          result = described_class.load_and_merge(base_file.path, missing_path)
        }.not_to raise_error
        expect(result).to eq(YAML.safe_load(base_yaml))
      end
    end

    context "when the base YAML contains a disallowed Ruby tag" do
      let(:base_file) { write_yaml("exemption_types: !ruby/symbol caregiver_disability") }

      after { base_file.unlink }

      it "raises ConfigurationError with 'Invalid YAML' (Psych::DisallowedClass path)" do
        expect {
          described_class.load_and_merge(base_file.path, "/tmp/whatever.yml")
        }.to raise_error(CEConfiguration::ConfigurationError, /Invalid YAML/)
      end
    end

    context "when the base YAML is malformed" do
      let(:base_file) { write_yaml("exemption_types: :\n  bad indent: [unclosed") }

      after { base_file.unlink }

      it "raises ConfigurationError with 'Invalid YAML'" do
        expect {
          described_class.load_and_merge(base_file.path, "/tmp/whatever.yml")
        }.to raise_error(CEConfiguration::ConfigurationError, /Invalid YAML/)
      end
    end

    context "when the custom YAML is malformed" do
      let(:base_file) { write_yaml(base_yaml) }
      let(:custom_file) { write_yaml("exemption_types: :\n  bad indent: [unclosed") }

      after do
        base_file.unlink
        custom_file.unlink
      end

      it "raises ConfigurationError with 'Invalid YAML'" do
        expect {
          described_class.load_and_merge(base_file.path, custom_file.path)
        }.to raise_error(CEConfiguration::ConfigurationError, /Invalid YAML/)
      end
    end

    context "when the base file has a non-Hash top level" do
      let(:base_file) { write_yaml("- just\n- a\n- list\n") }

      after { base_file.unlink }

      it "raises ConfigurationError matching 'Expected a Hash at top level'" do
        expect {
          described_class.load_and_merge(base_file.path, "/tmp/whatever.yml")
        }.to raise_error(CEConfiguration::ConfigurationError, /Expected a Hash at top level/)
      end
    end

    context "when the custom file has a non-Hash top level" do
      let(:base_file) { write_yaml(base_yaml) }
      let(:custom_file) { write_yaml("- just\n- a\n- list\n") }

      after do
        base_file.unlink
        custom_file.unlink
      end

      it "raises ConfigurationError matching 'Expected a Hash at top level'" do
        expect {
          described_class.load_and_merge(base_file.path, custom_file.path)
        }.to raise_error(CEConfiguration::ConfigurationError, /Expected a Hash at top level/)
      end
    end
  end

  describe ".transform_exemption_types" do
    context "with a well-formed hash-of-hashes (happy path)" do
      let(:ce_data) do
        {
          "exemption_types" => {
            "caregiver_child" => { "enabled" => true, "display_order" => 1 },
            "medical_condition" => { "enabled" => true }
          }
        }
      end

      it "returns an array of entries with id as Symbol and enabled as Boolean" do
        result = described_class.transform_exemption_types(ce_data)
        expect(result).to be_an(Array)
        expect(result.first[:id]).to be_a(Symbol)
        expect(result.first[:enabled]).to satisfy { |v| v == true || v == false }
      end

      # Regression guard for the `attrs.symbolize_keys.merge(id: id.to_sym)`
      # pass-through (vs. hardcoded `{id:, enabled:}` narrowing). If a future
      # refactor narrows the merge to only well-known keys, this assertion
      # will fail.
      it "passes through extra entry attributes unchanged (future-proofing guard)" do
        result = described_class.transform_exemption_types(ce_data)
        entry = result.find { |e| e[:id] == :caregiver_child }
        expect(entry[:display_order]).to eq(1)
      end
    end

    context "when exemption_types top-level key is missing" do
      it "raises ConfigurationError" do
        expect {
          described_class.transform_exemption_types({ "something_else" => {} })
        }.to raise_error(CEConfiguration::ConfigurationError, /exemption_types/)
      end
    end

    context "when an entry value is not a Hash" do
      it "raises ConfigurationError mentioning the offending id" do
        ce_data = { "exemption_types" => { "medical_condition" => true } }
        expect {
          described_class.transform_exemption_types(ce_data)
        }.to raise_error(CEConfiguration::ConfigurationError, /medical_condition/)
      end
    end

    context "when an entry is missing the enabled field" do
      it "raises ConfigurationError mentioning the offending id" do
        ce_data = { "exemption_types" => { "medical_condition" => {} } }
        expect {
          described_class.transform_exemption_types(ce_data)
        }.to raise_error(CEConfiguration::ConfigurationError, /medical_condition/)
      end
    end

    # Locks Hash#fetch semantics: the block fires only on missing keys, not
    # on falsy values. enabled: false must round-trip as Boolean false rather
    # than triggering the missing-field error path.
    context "when enabled is explicitly set to false (round-trip)" do
      let(:base_file) { write_yaml(base_yaml) }
      let(:custom_file) do
        write_yaml(<<~YAML)
          exemption_types:
            substance_treatment:
              enabled: false
        YAML
      end

      after do
        base_file.unlink
        custom_file.unlink
      end

      it "preserves enabled: false as Boolean false through load_and_merge + transform" do
        merged = described_class.load_and_merge(base_file.path, custom_file.path)
        result = described_class.transform_exemption_types(merged)
        entry = result.find { |e| e[:id] == :substance_treatment }
        expect(entry[:enabled]).to be false
      end
    end
  end

  describe "integration" do
    it "module-direct against real fixture returns the 7 OSCER defaults, all enabled" do
      base_path = Rails.root.join("config/ce_config_base.yml")
      custom_path = Rails.root.join("config/ce_config.yml")
      merged = described_class.load_and_merge(base_path, custom_path)
      result = described_class.transform_exemption_types(merged)

      expected_ids = %i[
        caregiver_disability
        caregiver_child
        medical_condition
        substance_treatment
        incarceration
        education_and_training
        received_medical_care
      ]
      expect(result.map { |e| e[:id] }).to match_array(expected_ids)
      expect(result.map { |e| e[:enabled] }).to all(be true)
    end

    # Initializer-wired boot test: catches initializer-wiring regressions
    # (e.g., missing explicit require, name typo on Rails.application.config)
    # that module-direct tests can't see.
    it "Rails.application.config.exemption_types is wired by the initializer on boot" do
      types = Rails.application.config.exemption_types
      expect(types).to be_an(Array)
      expected_ids = %i[
        caregiver_disability
        caregiver_child
        medical_condition
        substance_treatment
        incarceration
        education_and_training
        received_medical_care
      ]
      expect(types.map { |e| e[:id] }).to match_array(expected_ids)
      expect(types.map { |e| e[:enabled] }).to all(be true)
    end
  end
end
