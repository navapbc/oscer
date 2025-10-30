# frozen_string_literal: true

require "rails_helper"

valid_password = "password1234"

RSpec.describe Users::RegistrationForm do
  let (:form) { described_class.new() }

  it "passes validation with valid email and password" do
    form.email = "test@example.com"
    form.password = valid_password
    form.password_confirmation = valid_password

    expect(form).to be_valid
  end

  it "requires email and password" do
    form.email = ""
    form.password = ""

    expect(form).not_to be_valid
    expect(form.errors).to be_of_kind(:email, :blank)
    expect(form.errors).to be_of_kind(:password, :blank)
  end

  it "confirms the password matches" do
    form.password = valid_password
    form.password_confirmation = "not_the_same"

    expect(form).not_to be_valid
    expect(form.errors).to be_of_kind(:password_confirmation, :confirmation)
  end

  it "requires a valid email" do
    form.email = "not_an_email"

    expect(form).not_to be_valid
    expect(form.errors).to be_of_kind(:email, :invalid)
  end

  it "requires the honeypot field is empty" do
    form.email = "test@example.com"
    form.password = valid_password
    form.spam_trap = "I am a bot"

    expect(form).not_to be_valid
    expect(form.errors).to be_of_kind(:spam_trap, :present)
  end
end
