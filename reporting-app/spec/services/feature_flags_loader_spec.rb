# frozen_string_literal: true

require "rails_helper"
require "tempfile"

RSpec.describe FeatureFlagsLoader, type: :service do
  # Helper: write content to a tempfile and return the closed Tempfile.
  # Callers should `.unlink` in an `after` block and use `.path` for paths.
  def write_yaml(content)
    file = Tempfile.new([ "feature_flags_test", ".yml" ])
    file.write(content)
    file.close
    file
  end

  # The OSCER-shipped built-ins the loader merges deployment flags on top of.
  # Mirrors the real Features::FEATURE_FLAGS shape so collision/merge behavior
  # is exercised without depending on the live constant.
  let(:built_ins) do
    {
      doc_ai: {
        env_var: "FEATURE_DOC_AI",
        default: false,
        description: "Enable DocAI document analysis for income verification"
      }
    }
  end

  describe ".safe_load_optional" do
    context "when the file does not exist" do
      it "returns an empty hash without raising" do
        missing_path = "/tmp/definitely_not_a_real_flags_override_#{SecureRandom.hex}.yml"
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
          realtime_progress:
            env_var: FEATURE_REALTIME_PROGRESS
            default: false
        YAML
      end

      after { override_file.unlink }

      it "returns the parsed hash with string keys" do
        result = described_class.safe_load_optional(override_file.path)
        expect(result).to eq(
          "realtime_progress" => { "env_var" => "FEATURE_REALTIME_PROGRESS", "default" => false }
        )
      end
    end

    context "when the YAML contains a disallowed Ruby tag" do
      let(:disallowed_file) { write_yaml("realtime_progress: !ruby/symbol enabled") }

      after { disallowed_file.unlink }

      it "raises ConfigurationError with 'Invalid YAML'" do
        expect {
          described_class.safe_load_optional(disallowed_file.path)
        }.to raise_error(FeatureFlagsLoader::ConfigurationError, /Invalid YAML/)
      end
    end

    context "when the YAML is malformed" do
      let(:malformed_file) { write_yaml("realtime_progress: :\n  bad indent: [unclosed") }

      after { malformed_file.unlink }

      it "raises ConfigurationError with 'Invalid YAML'" do
        expect {
          described_class.safe_load_optional(malformed_file.path)
        }.to raise_error(FeatureFlagsLoader::ConfigurationError, /Invalid YAML/)
      end
    end

    context "when the YAML has a non-Hash top level" do
      let(:list_file) { write_yaml("- just\n- a\n- list\n") }

      after { list_file.unlink }

      it "raises ConfigurationError matching 'Expected a Hash at top level'" do
        expect {
          described_class.safe_load_optional(list_file.path)
        }.to raise_error(FeatureFlagsLoader::ConfigurationError, /Expected a Hash at top level/)
      end
    end
  end

  describe ".build_registry" do
    context "with no deployment overrides" do
      it "returns the built-ins verbatim (symbolized), nothing added" do
        result = described_class.build_registry(built_ins, {})
        expect(result.keys).to eq(%i[doc_ai])
        expect(result[:doc_ai]).to eq(built_ins[:doc_ai])
      end
    end

    context "with a well-formed deployment flag (happy path)" do
      let(:overrides) do
        {
          "realtime_progress" => {
            "env_var" => "FEATURE_REALTIME_PROGRESS",
            "default" => false,
            "description" => "Enable WebSocket real-time progress updates"
          }
        }
      end

      it "adds the deployment flag alongside the built-ins, keyed by Symbol" do
        result = described_class.build_registry(built_ins, overrides)
        expect(result.keys).to match_array(%i[doc_ai realtime_progress])
      end

      it "symbolizes the entry attribute keys and preserves values" do
        result = described_class.build_registry(built_ins, overrides)
        entry = result[:realtime_progress]
        expect(entry).to eq(
          env_var: "FEATURE_REALTIME_PROGRESS",
          default: false,
          description: "Enable WebSocket real-time progress updates"
        )
      end

      it "preserves default: true as Boolean true" do
        overrides = {
          "beta_dashboard" => { "env_var" => "FEATURE_BETA_DASHBOARD", "default" => true }
        }
        result = described_class.build_registry(built_ins, overrides)
        expect(result[:beta_dashboard][:default]).to be true
      end

      it "preserves default: false as Boolean false" do
        result = described_class.build_registry(built_ins, overrides)
        expect(result[:realtime_progress][:default]).to be false
      end

      it "leaves the built-ins untouched" do
        result = described_class.build_registry(built_ins, overrides)
        expect(result[:doc_ai]).to eq(built_ins[:doc_ai])
      end
    end

    context "when a deployment entry value is not a Hash" do
      it "raises ConfigurationError naming the offending flag" do
        expect {
          described_class.build_registry(built_ins, "realtime_progress" => true)
        }.to raise_error(FeatureFlagsLoader::ConfigurationError, /realtime_progress.*expected Hash/i)
      end
    end

    context "when a deployment entry is missing env_var" do
      it "raises ConfigurationError naming the flag and the env_var field" do
        expect {
          described_class.build_registry(built_ins, "realtime_progress" => { "default" => false })
        }.to raise_error(FeatureFlagsLoader::ConfigurationError, /realtime_progress.*env_var/)
      end
    end

    context "when a deployment entry has an env_var that does not match FEATURE_<NAME> shape" do
      it "raises ConfigurationError naming the flag and the env_var field" do
        overrides = {
          "realtime_progress" => { "env_var" => "REALTIME_PROGRESS", "default" => false }
        }
        expect {
          described_class.build_registry(built_ins, overrides)
        }.to raise_error(FeatureFlagsLoader::ConfigurationError, /realtime_progress.*env_var/)
      end

      it "rejects lowercase env_var names" do
        overrides = {
          "realtime_progress" => { "env_var" => "feature_realtime", "default" => false }
        }
        expect {
          described_class.build_registry(built_ins, overrides)
        }.to raise_error(FeatureFlagsLoader::ConfigurationError, /realtime_progress.*env_var/)
      end
    end

    context "when a deployment entry is missing default" do
      it "raises ConfigurationError naming the flag and the default field" do
        overrides = {
          "realtime_progress" => { "env_var" => "FEATURE_REALTIME_PROGRESS" }
        }
        expect {
          described_class.build_registry(built_ins, overrides)
        }.to raise_error(FeatureFlagsLoader::ConfigurationError, /realtime_progress.*default/)
      end
    end

    context "when a deployment entry has a non-boolean default" do
      it "raises ConfigurationError naming the flag and the default field for a string" do
        overrides = {
          "realtime_progress" => { "env_var" => "FEATURE_REALTIME_PROGRESS", "default" => "false" }
        }
        expect {
          described_class.build_registry(built_ins, overrides)
        }.to raise_error(FeatureFlagsLoader::ConfigurationError, /realtime_progress.*default/)
      end

      it "raises ConfigurationError for a nil default" do
        overrides = {
          "realtime_progress" => { "env_var" => "FEATURE_REALTIME_PROGRESS", "default" => nil }
        }
        expect {
          described_class.build_registry(built_ins, overrides)
        }.to raise_error(FeatureFlagsLoader::ConfigurationError, /realtime_progress.*default/)
      end
    end

    context "when a deployment entry collides with an OSCER-shipped built-in" do
      it "raises ConfigurationError naming the colliding flag (additive only)" do
        overrides = {
          "doc_ai" => { "env_var" => "FEATURE_DOC_AI", "default" => true }
        }
        expect {
          described_class.build_registry(built_ins, overrides)
        }.to raise_error(FeatureFlagsLoader::ConfigurationError, /doc_ai/)
      end
    end

    context "when a deployment entry reuses a built-in's env_var under a different name" do
      it "raises ConfigurationError (cannot shadow a built-in's env var)" do
        overrides = {
          "doc_ai_alias" => { "env_var" => "FEATURE_DOC_AI", "default" => false }
        }
        expect {
          described_class.build_registry(built_ins, overrides)
        }.to raise_error(FeatureFlagsLoader::ConfigurationError, /doc_ai_alias.*env_var.*in use/i)
      end
    end

    context "when two deployment entries share the same env_var" do
      it "raises ConfigurationError naming the second flag" do
        overrides = {
          "flag_one" => { "env_var" => "FEATURE_SHARED", "default" => false },
          "flag_two" => { "env_var" => "FEATURE_SHARED", "default" => true }
        }
        expect {
          described_class.build_registry(built_ins, overrides)
        }.to raise_error(FeatureFlagsLoader::ConfigurationError, /flag_two.*env_var.*in use/i)
      end
    end

    context "when a deployment entry has an unknown key (e.g. a typo'd field)" do
      it "raises ConfigurationError naming the unknown key" do
        overrides = {
          "realtime_progress" => {
            "env_var" => "FEATURE_REALTIME_PROGRESS",
            "default" => false,
            "descrption" => "typo'd 'description'"
          }
        }
        expect {
          described_class.build_registry(built_ins, overrides)
        }.to raise_error(FeatureFlagsLoader::ConfigurationError, /realtime_progress.*unknown key.*descrption/i)
      end
    end

    context "when a deployment entry name is not snake_case" do
      it "rejects a kebab-case name (would define an uncallable predicate)" do
        overrides = {
          "realtime-progress" => { "env_var" => "FEATURE_REALTIME_PROGRESS", "default" => false }
        }
        expect {
          described_class.build_registry(built_ins, overrides)
        }.to raise_error(FeatureFlagsLoader::ConfigurationError, /realtime-progress.*snake_case/i)
      end

      it "rejects a name with a leading digit" do
        overrides = {
          "2fa" => { "env_var" => "FEATURE_2FA", "default" => false }
        }
        expect {
          described_class.build_registry(built_ins, overrides)
        }.to raise_error(FeatureFlagsLoader::ConfigurationError, /2fa.*snake_case/i)
      end

      it "rejects a CamelCase name" do
        overrides = {
          "BetaDashboard" => { "env_var" => "FEATURE_BETA_DASHBOARD", "default" => false }
        }
        expect {
          described_class.build_registry(built_ins, overrides)
        }.to raise_error(FeatureFlagsLoader::ConfigurationError, /BetaDashboard.*snake_case/i)
      end

      it "rejects a non-String name (e.g. an unquoted numeric YAML key) with a ConfigurationError, not a crash" do
        overrides = {
          42 => { "env_var" => "FEATURE_FORTY_TWO", "default" => false }
        }
        expect {
          described_class.build_registry(built_ins, overrides)
        }.to raise_error(FeatureFlagsLoader::ConfigurationError, /snake_case/i)
      end

      it "accepts a snake_case name with digits and underscores" do
        overrides = {
          "beta_dashboard_v2" => { "env_var" => "FEATURE_BETA_DASHBOARD_V2", "default" => false }
        }
        result = described_class.build_registry(built_ins, overrides)
        expect(result.keys).to include(:beta_dashboard_v2)
      end
    end
  end
end
