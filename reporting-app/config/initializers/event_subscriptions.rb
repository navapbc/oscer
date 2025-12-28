# frozen_string_literal: true

# Register event listeners for domain events.
# This sets up subscriptions after the application is fully initialized
# to ensure all classes are loaded.
Rails.application.config.after_initialize do
  NotificationsEventListener.subscribe
end
