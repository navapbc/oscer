# frozen_string_literal: true

# Custom RSpec matcher for testing Strata event publishing
RSpec::Matchers.define :have_published_event do |event_name|
  supports_block_expectations

  match do |block|
    @event_published = false

    allow(Strata::EventManager).to receive(:publish) do |name, payload|
      @event_published = true if name == event_name
    end

    block.call
    @event_published
  end

  failure_message do
    "expected #{event_name} event to be published, but it was not"
  end

  failure_message_when_negated do
    "expected #{event_name} event not to be published, but it was"
  end
end
