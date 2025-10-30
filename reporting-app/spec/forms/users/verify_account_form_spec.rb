# frozen_string_literal: true

require "rails_helper"

RSpec.describe Users::VerifyAccountForm do
  it "passes validation with valid email and code" do
    form = described_class.new(email: "test@example.com", code: "123456")

    expect(form).to be_valid
  end

  it "requires email and code" do
    form = described_class.new(email: nil, code: nil)

    expect(form).to be_invalid
    expect(form.errors).to be_of_kind(:email, :blank)
    expect(form.errors).to be_of_kind(:code, :blank)
  end

  it "requires email to be a valid email" do
    form = described_class.new(email: "invalid-email", code: "123456")

    expect(form).to be_invalid
    expect(form.errors).to be_of_kind(:email, :invalid)
  end

  it "requires code to be 6 characters" do
    form = described_class.new(email: "test@example.com", code: "12345")

    expect(form).to be_invalid
    expect(form.errors).to be_of_kind(:code, :wrong_length)
  end
end
