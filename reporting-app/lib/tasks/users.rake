# frozen_string_literal: true

namespace :users do
  desc "Update a user by email with full_name, role, and/or region attributes"
  task update: :environment do
    # Parse flag-style arguments from ARGV (e.g., --email=user@example.com --full_name="John")
    args = {}
    ARGV.each do |arg|
      next unless arg.start_with?("--")

      key, value = arg[2..-1].split("=", 2)
      next unless key.present?

      args[key.to_sym] = value
    end

    # Remove rake task name and arguments from ARGV to avoid rake errors
    ARGV.clear

    email = args[:email]
    raise "Error: email is required" unless email.present?

    user = User.find_by(email:)
    raise "Error: User with email '#{email}' not found" unless user

    updates = {}
    updates[:full_name] = args[:full_name] if args.key?(:full_name)
    updates[:role] = args[:role] if args.key?(:role)
    updates[:region] = args[:region] if args.key?(:region)

    if updates.empty?
      Rails.logger.warn "No attributes provided to update for user '#{email}'"
      return
    end

    if user.update(updates)
      Rails.logger.info "Successfully updated user '#{email}' with: #{updates.inspect}"
    else
      error_messages = user.errors.full_messages.join(", ")
      raise "Error updating user '#{email}': #{error_messages}"
    end
  end
end
