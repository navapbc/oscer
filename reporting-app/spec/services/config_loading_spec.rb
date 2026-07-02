# frozen_string_literal: true

require "rails_helper"

# Direct regression net for the plumbing extracted from ExemptionTypesLoader and
# FeatureFlagsLoader. The module is exercised through a throwaway anonymous module that
# `extend`s it — mirroring how the real loaders consume it (`extend ConfigLoading`) and
# proving the methods land as PUBLIC singleton methods. `write_yaml` comes from the shared
# spec/support/yaml_config_helpers.rb helper.
RSpec.describe ConfigLoading, type: :service do
  # A stand-in for a real loader: gains safe_load_optional / parse_yaml as public
  # singleton methods, just as `extend ConfigLoading` does on ExemptionTypesLoader et al.
  let(:loader) { Module.new { extend ConfigLoading } }

  it "exposes the plumbing as public methods after extend" do
    expect(loader.singleton_class.public_method_defined?(:safe_load_optional)).to be(true)
    expect(loader.singleton_class.public_method_defined?(:parse_yaml)).to be(true)
  end

  it "defines ConfigurationError as a StandardError subclass" do
    expect(described_class::ConfigurationError.ancestors).to include(StandardError)
  end

  describe "#safe_load_optional" do
    context "when the file does not exist" do
      it "returns an empty hash without raising" do
        missing_path = "/tmp/definitely_not_a_real_override_#{SecureRandom.hex}.yml"
        result = nil
        expect {
          result = loader.safe_load_optional(missing_path)
        }.not_to raise_error
        expect(result).to eq({})
      end
    end

    context "when the file is empty (parses to nil)" do
      let(:empty_file) { write_yaml("") }

      after { empty_file.unlink }

      it "returns an empty hash without raising" do
        expect(loader.safe_load_optional(empty_file.path)).to eq({})
      end
    end

    context "when the file contains only comments (parses to nil)" do
      let(:comments_only_file) { write_yaml("# just a comment\n# another comment\n") }

      after { comments_only_file.unlink }

      it "returns an empty hash without raising" do
        expect(loader.safe_load_optional(comments_only_file.path)).to eq({})
      end
    end

    context "when the file contains a literal empty hash" do
      let(:empty_hash_file) { write_yaml("{}\n") }

      after { empty_hash_file.unlink }

      it "returns an empty hash" do
        expect(loader.safe_load_optional(empty_hash_file.path)).to eq({})
      end
    end

    context "when the file contains a valid override hash" do
      let(:override_file) do
        write_yaml(<<~YAML)
          medical_condition:
            enabled: false
          disaster_evacuation:
            enabled: true
        YAML
      end

      after { override_file.unlink }

      it "returns the parsed hash unchanged (string keys, no transform)" do
        result = loader.safe_load_optional(override_file.path)
        expect(result).to eq(
          "medical_condition" => { "enabled" => false },
          "disaster_evacuation" => { "enabled" => true }
        )
      end
    end

    context "when the YAML contains a disallowed Ruby tag" do
      let(:disallowed_file) { write_yaml("medical_condition: !ruby/symbol enabled") }

      after { disallowed_file.unlink }

      it "raises ConfigurationError matching 'Invalid YAML'" do
        expect {
          loader.safe_load_optional(disallowed_file.path)
        }.to raise_error(ConfigLoading::ConfigurationError, /Invalid YAML/)
      end
    end

    context "when the YAML is malformed" do
      let(:malformed_file) { write_yaml("medical_condition: :\n  bad indent: [unclosed") }

      after { malformed_file.unlink }

      it "raises ConfigurationError matching 'Invalid YAML'" do
        expect {
          loader.safe_load_optional(malformed_file.path)
        }.to raise_error(ConfigLoading::ConfigurationError, /Invalid YAML/)
      end
    end

    context "when the YAML has a non-Hash top level" do
      let(:list_file) { write_yaml("- just\n- a\n- list\n") }

      after { list_file.unlink }

      it "raises ConfigurationError matching 'Expected a Hash at top level'" do
        expect {
          loader.safe_load_optional(list_file.path)
        }.to raise_error(ConfigLoading::ConfigurationError, /Expected a Hash at top level/)
      end
    end
  end

  describe "#parse_yaml" do
    # parse_yaml is public and skips the File.exist? guard that safe_load_optional adds.
    context "with a well-formed hash file" do
      let(:hash_file) { write_yaml("feature_x:\n  enabled: true\n") }

      after { hash_file.unlink }

      it "returns the parsed hash" do
        expect(loader.parse_yaml(hash_file.path)).to eq("feature_x" => { "enabled" => true })
      end
    end

    context "with a non-Hash top level" do
      let(:scalar_file) { write_yaml("just a string\n") }

      after { scalar_file.unlink }

      it "names the offending file's top-level class in the error" do
        expect {
          loader.parse_yaml(scalar_file.path)
        }.to raise_error(ConfigLoading::ConfigurationError, /Expected a Hash at top level.*String/)
      end
    end
  end
end
