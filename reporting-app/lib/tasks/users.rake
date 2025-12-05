# frozen_string_literal: true

namespace :users do
  desc "Update a user by email with full_name, role, and/or region attributes"
  task :update, [ :email, :full_name, :role, :region ] => [ :environment ] do |t, args|
    email = fetch_required_args!(args, :email).first
    user = User.find_by(email:)
    raise "Error: User with email '#{email}' not found" unless user

    args.with_defaults(full_name: nil, role: nil, region: nil)

    if user.update(args.to_h)
      Rails.logger.info "Successfully updated user '#{email}' with: #{user.changes.inspect}"
    else
      error_messages = user.errors.full_messages.join(", ")
      raise "Error updating user '#{email}': #{error_messages}"
    end
  end
end
