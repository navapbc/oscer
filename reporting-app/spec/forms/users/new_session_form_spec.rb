# frozen_string_literal: true

require "rails_helper"

RSpec.describe Users::NewSessionForm do
  it "passes validation with valid email and password" do
    form = described_class.new(
      email: "test@example.com",
      password: "password"
    )

    expect(form).to be_valid
  end

  it "requires email and password" do
    form = described_class.new({
      email: "",
      password: ""
    })

    expect(form).not_to be_valid
    expect(form.errors).to be_of_kind(:email, :blank)
    expect(form.errors).to be_of_kind(:password, :blank)
  end

  it "requires a valid email" do
    form = described_class.new(
      email: "not_an_email"
    )

    expect(form).not_to be_valid
    expect(form.errors).to be_of_kind(:email, :invalid)
  end

  it "requires the honeypot field to be empty" do
    form = described_class.new(
      email: "test@example.com",
      password: "password",
      spam_trap: "I am a bot"
    )

    expect(form).not_to be_valid
    expect(form.errors).to be_of_kind(:spam_trap, :present)
  end
end
