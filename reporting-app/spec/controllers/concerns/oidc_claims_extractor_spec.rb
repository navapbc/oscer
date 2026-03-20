# frozen_string_literal: true

require "rails_helper"

RSpec.describe OidcClaimsExtractor do
  let(:extractor) { Class.new { include OidcClaimsExtractor }.new }

  let(:auth) do
    OmniAuth::AuthHash.new(
      uid: "user-123",
      extra: {
        raw_info: {
          "sub" => "user-123",
          "email" => "staff@example.gov",
          "name" => "Jane Doe",
          "groups" => [ "OSCER-Caseworker" ],
          "custom:region" => "Northeast"
        }
      }
    )
  end

  describe "#extract_oidc_claims" do
    context "with staff-style config (includes groups and region)" do
      let(:config) do
        {
          email: "email",
          name: "name",
          unique_id: "sub",
          groups: "groups",
          region: "custom:region"
        }
      end

      it "returns uid, email, name, groups, and region" do
        claims = extractor.extract_oidc_claims(auth, config)

        expect(claims[:uid]).to eq("user-123")
        expect(claims[:email]).to eq("staff@example.gov")
        expect(claims[:name]).to eq("Jane Doe")
        expect(claims[:groups]).to eq([ "OSCER-Caseworker" ])
        expect(claims[:region]).to eq("Northeast")
      end
    end

    context "with member-style config (uid, email, name only)" do
      let(:config) do
        {
          email: "email",
          name: "name",
          unique_id: "sub"
        }
      end

      it "returns only uid, email, and name" do
        claims = extractor.extract_oidc_claims(auth, config)

        expect(claims[:uid]).to eq("user-123")
        expect(claims[:email]).to eq("staff@example.gov")
        expect(claims[:name]).to eq("Jane Doe")
        expect(claims).not_to have_key(:groups)
        expect(claims).not_to have_key(:region)
      end
    end

    context "when unique_id is missing from config" do
      let(:config) { { email: "email", name: "name" } }

      it "falls back to auth.uid" do
        claims = extractor.extract_oidc_claims(auth, config)

        expect(claims[:uid]).to eq("user-123")
      end
    end
  end

  describe "#sanitized_failure_message" do
    it "returns allowlisted messages as-is" do
      expect(extractor.sanitized_failure_message("invalid_credentials")).to eq("invalid_credentials")
      expect(extractor.sanitized_failure_message("timeout")).to eq("timeout")
    end

    it "returns unknown_error for non-allowlisted message" do
      expect(extractor.sanitized_failure_message("csrf_detected")).to eq("unknown_error")
      expect(extractor.sanitized_failure_message("malicious<script>")).to eq("unknown_error")
    end

    it "returns unknown_error for blank or nil" do
      expect(extractor.sanitized_failure_message("")).to eq("unknown_error")
      expect(extractor.sanitized_failure_message(nil)).to eq("unknown_error")
      expect(extractor.sanitized_failure_message("   ")).to eq("unknown_error")
    end
  end
end
