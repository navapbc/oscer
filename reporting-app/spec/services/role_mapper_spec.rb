# frozen_string_literal: true

require "rails_helper"

RSpec.describe RoleMapper, type: :service do
  describe "#initialize" do
    context "with valid configuration" do
      it "loads configuration successfully" do
        expect { described_class.new(config: mock_role_mapping_config) }.not_to raise_error
      end
    end

    context "with valid configuration file" do
      it "loads from default config path" do
        expect { described_class.new }.not_to raise_error
      end
    end

    context "with missing configuration file" do
      it "raises ConfigurationError" do
        expect {
          described_class.new(config_path: "/nonexistent/path.yml")
        }.to raise_error(RoleMapper::ConfigurationError, /not found/)
      end
    end

    context "with invalid YAML file" do
      let(:invalid_yaml_path) { Rails.root.join("tmp/invalid_role_mapping.yml") }

      before do
        FileUtils.mkdir_p(Rails.root.join("tmp"))
        File.write(invalid_yaml_path, "invalid: yaml: syntax: [")
      end

      after do
        File.delete(invalid_yaml_path) if File.exist?(invalid_yaml_path)
      end

      it "raises ConfigurationError" do
        expect {
          described_class.new(config_path: invalid_yaml_path)
        }.to raise_error(RoleMapper::ConfigurationError, /Invalid YAML/)
      end
    end

    context "with missing environment section" do
      let(:config_path) { Rails.root.join("tmp/missing_env_role_mapping.yml") }

      before do
        FileUtils.mkdir_p(Rails.root.join("tmp"))
        File.write(config_path, <<~YAML)
          production:
            role_mappings:
              admin:
                - "OSCER-Admin"
            no_match_behavior: deny
            default_role: null
        YAML
      end

      after do
        File.delete(config_path) if File.exist?(config_path)
      end

      it "raises ConfigurationError for unknown environment" do
        expect {
          described_class.new(config_path: config_path, environment: "staging")
        }.to raise_error(RoleMapper::ConfigurationError, /No configuration found for environment: staging/)
      end
    end

    context "with missing role_mappings" do
      it "raises ConfigurationError" do
        config = mock_role_mapping_config.except(:role_mappings)

        expect {
          described_class.new(config: config)
        }.to raise_error(RoleMapper::ConfigurationError, /role_mappings key is required/)
      end
    end

    context "with empty role_mappings" do
      it "raises ConfigurationError" do
        # Can't use deep_merge for this - need to fully replace role_mappings
        config = {
          role_mappings: {},
          no_match_behavior: "deny",
          default_role: nil
        }

        expect {
          described_class.new(config: config)
        }.to raise_error(RoleMapper::ConfigurationError, /cannot be empty/)
      end
    end

    context "with invalid no_match_behavior" do
      it "raises ConfigurationError" do
        config = mock_role_mapping_config(no_match_behavior: "invalid")

        expect {
          described_class.new(config: config)
        }.to raise_error(RoleMapper::ConfigurationError, /no_match_behavior must be/)
      end
    end

    context "with non-array role_mappings value" do
      it "raises ConfigurationError" do
        config = mock_role_mapping_config(role_mappings: { admin: "OSCER-Admin" })

        expect {
          described_class.new(config: config)
        }.to raise_error(RoleMapper::ConfigurationError, /must be an array/)
      end
    end
  end

  describe "#map_groups_to_role" do
    subject(:mapper) { described_class.new(config: mock_role_mapping_config) }

    context "with single matching group" do
      it "returns admin for OSCER-Admin group" do
        expect(mapper.map_groups_to_role([ "OSCER-Admin" ])).to eq("admin")
      end

      it "returns caseworker for OSCER-Caseworker group" do
        expect(mapper.map_groups_to_role([ "OSCER-Caseworker" ])).to eq("caseworker")
      end

      it "returns admin for alternative CE-Administrators group" do
        expect(mapper.map_groups_to_role([ "CE-Administrators" ])).to eq("admin")
      end

      it "returns caseworker for alternative CE-Staff group" do
        expect(mapper.map_groups_to_role([ "CE-Staff" ])).to eq("caseworker")
      end
    end

    context "with multiple groups" do
      it "returns the first matching role based on config order" do
        # admin comes before caseworker in config, so admin wins
        groups = [ "OSCER-Caseworker", "OSCER-Admin" ]
        expect(mapper.map_groups_to_role(groups)).to eq("admin")
      end

      it "ignores non-matching groups" do
        groups = [ "Random-Group", "OSCER-Staff", "Another-Group" ]
        expect(mapper.map_groups_to_role(groups)).to eq("caseworker")
      end
    end

    context "with case-insensitive matching" do
      it "matches lowercase group" do
        expect(mapper.map_groups_to_role([ "oscer-admin" ])).to eq("admin")
      end

      it "matches uppercase group" do
        expect(mapper.map_groups_to_role([ "OSCER-ADMIN" ])).to eq("admin")
      end

      it "matches mixed case group" do
        expect(mapper.map_groups_to_role([ "Oscer-Admin" ])).to eq("admin")
      end

      it "handles case variations in multiple groups" do
        groups = [ "oscer-staff", "CE-ADMINISTRATORS" ]
        expect(mapper.map_groups_to_role(groups)).to eq("admin")
      end
    end

    context "with no matching groups" do
      it "returns nil for unknown group" do
        expect(mapper.map_groups_to_role([ "Unknown-Group" ])).to be_nil
      end

      it "returns nil for empty array" do
        expect(mapper.map_groups_to_role([])).to be_nil
      end

      it "returns nil for nil input" do
        expect(mapper.map_groups_to_role(nil)).to be_nil
      end
    end

    context "with role priority" do
      subject(:mapper) do
        # Can't use deep_merge - need exact ordering control
        # Admin listed first = higher priority (matches business expectation)
        config = {
          role_mappings: {
            admin: [ "Shared-Group", "Admin-Only" ],
            caseworker: [ "Shared-Group" ]
          },
          no_match_behavior: "deny",
          default_role: nil
        }
        described_class.new(config: config)
      end

      it "respects configuration order when multiple roles match" do
        # User belongs to Shared-Group which maps to both admin and caseworker
        # Admin wins because it's listed first in config
        expect(mapper.map_groups_to_role([ "Shared-Group" ])).to eq("admin")
      end
    end
  end

  describe "#deny_if_no_match?" do
    context "when no_match_behavior is deny" do
      subject(:mapper) { described_class.new(config: mock_role_mapping_config(no_match_behavior: "deny")) }

      it "returns true" do
        expect(mapper.deny_if_no_match?).to be true
      end
    end

    context "when no_match_behavior is assign_default" do
      subject(:mapper) { described_class.new(config: mock_role_mapping_config(no_match_behavior: "assign_default")) }

      it "returns false" do
        expect(mapper.deny_if_no_match?).to be false
      end
    end
  end

  describe "#default_role" do
    context "when default_role is nil" do
      subject(:mapper) { described_class.new(config: mock_role_mapping_config) }

      it "returns nil" do
        expect(mapper.default_role).to be_nil
      end
    end

    context "when default_role is configured" do
      subject(:mapper) do
        config = mock_role_mapping_config(
          no_match_behavior: "assign_default",
          default_role: "readonly"
        )
        described_class.new(config: config)
      end

      it "returns the configured default role" do
        expect(mapper.default_role).to eq("readonly")
      end
    end
  end

  describe "integration with config file" do
    context "with default (test) environment" do
      subject(:mapper) { described_class.new }

      it "loads configuration for current Rails environment" do
        expect { mapper }.not_to raise_error
      end

      it "maps admin groups correctly" do
        expect(mapper.map_groups_to_role([ "OSCER-Admin" ])).to eq("admin")
      end

      it "maps caseworker groups correctly" do
        expect(mapper.map_groups_to_role([ "OSCER-Caseworker" ])).to eq("caseworker")
      end

      it "denies access when no groups match" do
        expect(mapper.deny_if_no_match?).to be true
      end
    end

    context "with explicit environment parameter" do
      it "loads configuration for specified environment" do
        mapper = described_class.new(environment: "production")
        expect(mapper.map_groups_to_role([ "OSCER-Admin" ])).to eq("admin")
      end
    end
  end
end
