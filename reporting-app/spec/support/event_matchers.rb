# frozen_string_literal: true

# Custom RSpec matcher for testing Strata event publishing
# Based on flex-sdk's publish_event_with_payload matcher
RSpec::Matchers.define :have_published_event do |event_name|
  supports_block_expectations

  match do |block|
    @event_triggered = false
    @actual_payload = nil

    callback = ->(event) do
      @event_triggered = true
      @actual_payload = event[:payload]
    end

    subscription = Strata::EventManager.subscribe(event_name, callback)

    begin
      block.call
    ensure
      Strata::EventManager.unsubscribe(subscription) if subscription
    end

    @event_triggered
  end

  failure_message do
    "expected event '#{event_name}' to be published, but it was not triggered"
  end

  failure_message_when_negated do
    "expected event '#{event_name}' not to be published, but it was"
  end
end
