# frozen_string_literal: true

namespace :users do
  desc "Update a user by email with full_name, role, and/or region attributes"
  task :update, [ :email, :full_name, :role, :region ] => [ :environment ] do |t, args|
    email = fetch_required_args!(args, :email).first
    user = User.find_by(email:)
    raise "Error: User with email '#{email}' not found" unless user

    # Build update hash only with explicitly provided values
    update_hash = {}
    update_hash[:full_name] = args[:full_name] if args[:full_name] != ""
    update_hash[:role] = args[:role] if args[:role] != ""
    update_hash[:region] = args[:region] if args[:region] != ""

    if update_hash.empty?
      Rails.logger.info "No attributes provided to update for user '#{email}'"
    elsif user.update(update_hash)
      Rails.logger.info "Successfully updated user '#{email}' with: #{user.changes.inspect}"
    else
      error_messages = user.errors.full_messages.join(", ")
      raise "Error updating user '#{email}': #{error_messages}"
    end
  end
end
