# frozen_string_literal: true

require "rails_helper"

RSpec.describe MemberOidcProvisioner, type: :service do
  subject(:provisioner) { described_class.new }

  describe "#provision!" do
    context "with valid claims" do
      let(:claims) { mock_member_claims }

      it "creates a new user on first login" do
        expect { provisioner.provision!(claims) }.to change(User, :count).by(1)
      end

      it "returns the created user" do
        user = provisioner.provision!(claims)

        expect(user).to be_persisted
        expect(user.uid).to eq("member-user-456")
      end

      it "sets user attributes from claims" do
        user = provisioner.provision!(claims)

        expect(user.email).to eq("john.smith@example.com")
        expect(user.full_name).to eq("John Smith")
      end

      it "sets provider to member_oidc" do
        user = provisioner.provision!(claims)

        expect(user.provider).to eq("member_oidc")
      end

      it "does not set a role (members have no staff role)" do
        user = provisioner.provision!(claims)

        expect(user.role).to be_nil
      end

      it "handles nil name gracefully" do
        claims = mock_member_claims(name: nil)

        user = provisioner.provision!(claims)

        expect(user.full_name).to be_nil
      end

      it "sets mfa_preference to opt_out for new users" do
        user = provisioner.provision!(claims)

        expect(user.mfa_preference).to eq("opt_out")
      end
    end

    context "when user already exists" do
      let!(:existing_user) do
        User.create!(
          uid: "member-user-456",
          email: "old.email@example.com",
          full_name: "Old Name",
          provider: "member_oidc"
        )
      end

      it "finds existing user by UID" do
        claims = mock_member_claims

        expect { provisioner.provision!(claims) }.not_to change(User, :count)
      end

      it "updates email when changed in IdP" do
        claims = mock_member_claims(email: "new.email@example.com")

        expect { provisioner.provision!(claims) }
          .to change { existing_user.reload.email }
          .from("old.email@example.com")
          .to("new.email@example.com")
      end

      it "updates name when changed in IdP" do
        claims = mock_member_claims(name: "New Name")

        expect { provisioner.provision!(claims) }
          .to change { existing_user.reload.full_name }
          .from("Old Name")
          .to("New Name")
      end

      it "does not change role (members remain without role)" do
        claims = mock_member_claims

        provisioner.provision!(claims)

        expect(existing_user.reload.role).to be_nil
      end

      it "preserves mfa_preference if already set" do
        existing_user.update!(mfa_preference: "opt_out")
        claims = mock_member_claims

        provisioner.provision!(claims)

        expect(existing_user.reload.mfa_preference).to eq("opt_out")
      end

      it "sets mfa_preference to opt_out if not already set" do
        existing_user.update!(mfa_preference: nil)
        claims = mock_member_claims

        provisioner.provision!(claims)

        expect(existing_user.reload.mfa_preference).to eq("opt_out")
      end
    end

    context "with invalid claims" do
      it "raises ArgumentError when claims is nil" do
        expect { provisioner.provision!(nil) }
          .to raise_error(ArgumentError, /claims cannot be nil/)
      end

      it "raises ArgumentError when uid is missing" do
        claims = mock_member_claims.except(:uid)

        expect { provisioner.provision!(claims) }
          .to raise_error(ArgumentError, /uid is required/)
      end

      it "raises ArgumentError when uid is blank" do
        claims = mock_member_claims(uid: "")

        expect { provisioner.provision!(claims) }
          .to raise_error(ArgumentError, /uid is required/)
      end

      it "raises ArgumentError when email is missing" do
        claims = mock_member_claims.except(:email)

        expect { provisioner.provision!(claims) }
          .to raise_error(ArgumentError, /email is required/)
      end

      it "raises ArgumentError when email is blank" do
        claims = mock_member_claims(email: "")

        expect { provisioner.provision!(claims) }
          .to raise_error(ArgumentError, /email is required/)
      end
    end

    context "when user has existing role from staff SSO" do
      let!(:existing_user) do
        User.create!(
          uid: "member-user-456",
          email: "staff-turned-member@example.com",
          full_name: "Staff Member",
          provider: "sso",
          role: "caseworker"
        )
      end

      it "finds existing user by UID regardless of provider" do
        claims = mock_member_claims

        expect { provisioner.provision!(claims) }.not_to change(User, :count)
      end

      it "updates provider to member_oidc" do
        claims = mock_member_claims

        expect { provisioner.provision!(claims) }
          .to change { existing_user.reload.provider }
          .from("sso")
          .to("member_oidc")
      end

      it "preserves existing role (does not clear it)" do
        claims = mock_member_claims

        provisioner.provision!(claims)

        expect(existing_user.reload.role).to eq("caseworker")
      end
    end

    context "without role mapping (unlike staff provisioner)" do
      it "successfully provisions user without any role logic" do
        claims = mock_member_claims

        expect { provisioner.provision!(claims) }.not_to raise_error
      end

      it "returns a user without role" do
        claims = mock_member_claims

        user = provisioner.provision!(claims)

        expect(user.role).to be_nil
        expect(user).to be_persisted
      end
    end
  end
end
