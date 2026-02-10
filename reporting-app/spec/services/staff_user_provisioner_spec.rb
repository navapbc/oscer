# frozen_string_literal: true

require "rails_helper"

RSpec.describe StaffUserProvisioner, type: :service do
  let(:role_mapper) { instance_double(RoleMapper) }
  subject(:provisioner) { described_class.new(role_mapper: role_mapper) }

  before do
    allow(role_mapper).to receive(:map_groups_to_role).and_return("caseworker")
    allow(role_mapper).to receive(:deny_if_no_match?).and_return(true)
    allow(role_mapper).to receive(:default_role).and_return(nil)
  end

  describe "#provision!" do
    context "with valid claims" do
      let(:claims) { mock_staff_claims }

      it "creates a new user on first login" do
        expect { provisioner.provision!(claims) }.to change(User, :count).by(1)
      end

      it "returns the created user" do
        user = provisioner.provision!(claims)

        expect(user).to be_persisted
        expect(user.uid).to eq("staff-user-123")
      end

      it "sets user attributes from claims" do
        user = provisioner.provision!(claims)

        expect(user.email).to eq("jane.doe@example.gov")
        expect(user.full_name).to eq("Jane Doe")
      end

      it "sets provider to sso" do
        user = provisioner.provision!(claims)

        expect(user.provider).to eq("sso")
      end

      it "assigns role from RoleMapper" do
        allow(role_mapper).to receive(:map_groups_to_role)
          .with([ "OSCER-Caseworker" ])
          .and_return("caseworker")

        user = provisioner.provision!(claims)

        expect(user.role).to eq("caseworker")
      end

      it "handles nil name gracefully" do
        claims = mock_staff_claims(name: nil)

        user = provisioner.provision!(claims)

        expect(user.full_name).to be_nil
      end
    end

    context "when user already exists" do
      let!(:existing_user) do
        User.create!(
          uid: "staff-user-123",
          email: "old.email@example.gov",
          full_name: "Old Name",
          provider: "sso",
          role: "caseworker"
        )
      end

      it "finds existing user by UID" do
        claims = mock_staff_claims

        expect { provisioner.provision!(claims) }.not_to change(User, :count)
      end

      it "updates email when changed in IdP" do
        claims = mock_staff_claims(email: "new.email@example.gov")

        expect { provisioner.provision!(claims) }
          .to change { existing_user.reload.email }
          .from("old.email@example.gov")
          .to("new.email@example.gov")
      end

      it "updates name when changed in IdP" do
        claims = mock_staff_claims(name: "New Name")

        expect { provisioner.provision!(claims) }
          .to change { existing_user.reload.full_name }
          .from("Old Name")
          .to("New Name")
      end

      it "updates role when group membership changes" do
        allow(role_mapper).to receive(:map_groups_to_role)
          .with([ "OSCER-Admin" ])
          .and_return("admin")

        claims = mock_staff_claims(groups: [ "OSCER-Admin" ])

        expect { provisioner.provision!(claims) }
          .to change { existing_user.reload.role }
          .from("caseworker")
          .to("admin")
      end
    end

    context "when no matching role" do
      before do
        allow(role_mapper).to receive(:map_groups_to_role).and_return(nil)
      end

      context "with deny mode enabled" do
        before do
          allow(role_mapper).to receive(:deny_if_no_match?).and_return(true)
        end

        it "raises Auth::Errors::AccessDenied" do
          claims = mock_staff_claims(groups: [ "Unknown-Group" ])

          expect { provisioner.provision!(claims) }
            .to raise_error(Auth::Errors::AccessDenied)
        end

        it "does not create a user" do
          claims = mock_staff_claims(groups: [ "Unknown-Group" ])

          expect {
            provisioner.provision!(claims) rescue nil
          }.not_to change(User, :count)
        end
      end

      context "with assign_default mode" do
        before do
          allow(role_mapper).to receive(:deny_if_no_match?).and_return(false)
          allow(role_mapper).to receive(:default_role).and_return("readonly")
        end

        it "assigns the default role" do
          claims = mock_staff_claims(groups: [ "Unknown-Group" ])

          user = provisioner.provision!(claims)

          expect(user.role).to eq("readonly")
        end
      end

      context "with assign_default mode and nil default" do
        before do
          allow(role_mapper).to receive(:deny_if_no_match?).and_return(false)
          allow(role_mapper).to receive(:default_role).and_return(nil)
        end

        it "sets role to nil" do
          claims = mock_staff_claims(groups: [ "Unknown-Group" ])

          user = provisioner.provision!(claims)

          expect(user.role).to be_nil
        end
      end
    end

    context "with invalid claims" do
      it "raises ArgumentError when claims is nil" do
        expect { provisioner.provision!(nil) }
          .to raise_error(ArgumentError, /claims cannot be nil/)
      end

      it "raises ArgumentError when uid is missing" do
        claims = mock_staff_claims.except(:uid)

        expect { provisioner.provision!(claims) }
          .to raise_error(ArgumentError, /uid is required/)
      end

      it "raises ArgumentError when uid is blank" do
        claims = mock_staff_claims(uid: "")

        expect { provisioner.provision!(claims) }
          .to raise_error(ArgumentError, /uid is required/)
      end

      it "raises ArgumentError when email is missing" do
        claims = mock_staff_claims.except(:email)

        expect { provisioner.provision!(claims) }
          .to raise_error(ArgumentError, /email is required/)
      end

      it "raises ArgumentError when email is blank" do
        claims = mock_staff_claims(email: "")

        expect { provisioner.provision!(claims) }
          .to raise_error(ArgumentError, /email is required/)
      end
    end

    context "with nil groups" do
      before do
        allow(role_mapper).to receive(:map_groups_to_role).with(nil).and_return(nil)
        allow(role_mapper).to receive(:deny_if_no_match?).and_return(false)
        allow(role_mapper).to receive(:default_role).and_return("guest")
      end

      it "handles nil groups gracefully" do
        claims = mock_staff_claims(groups: nil)

        user = provisioner.provision!(claims)

        expect(user.role).to eq("guest")
      end
    end

    context "with empty groups" do
      before do
        allow(role_mapper).to receive(:map_groups_to_role).with([]).and_return(nil)
        allow(role_mapper).to receive(:deny_if_no_match?).and_return(false)
        allow(role_mapper).to receive(:default_role).and_return("guest")
      end

      it "handles empty groups gracefully" do
        claims = mock_staff_claims(groups: [])

        user = provisioner.provision!(claims)

        expect(user.role).to eq("guest")
      end
    end
  end

  describe "integration with real RoleMapper" do
    subject(:provisioner) { described_class.new }

    it "provisions admin user correctly" do
      claims = mock_staff_claims(
        uid: "admin-user",
        groups: [ "OSCER-Admin" ]
      )

      user = provisioner.provision!(claims)

      expect(user.role).to eq("admin")
      expect(user.admin?).to be true
    end

    it "provisions caseworker user correctly" do
      claims = mock_staff_claims(
        uid: "caseworker-user",
        groups: [ "OSCER-Caseworker" ]
      )

      user = provisioner.provision!(claims)

      expect(user.role).to eq("caseworker")
      expect(user.caseworker?).to be true
    end

    it "denies access for unknown groups" do
      claims = mock_staff_claims(
        uid: "unknown-user",
        groups: [ "Unknown-Group" ]
      )

      expect { provisioner.provision!(claims) }
        .to raise_error(Auth::Errors::AccessDenied)
    end
  end
end
