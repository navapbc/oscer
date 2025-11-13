# frozen_string_literal: true

# Custom RSpec matcher for testing database query counts
# Helps verify that batch loading optimizations are working correctly
#
# @example Test that queries don't exceed a limit
#   expect {
#     get some_path
#   }.not_to exceed_query_limit(10)

RSpec::Matchers.define :exceed_query_limit do |expected_limit|
  supports_block_expectations

  match do |block|
    query_count = count_queries(&block)
    @actual_count = query_count
    @expected_limit = expected_limit
    query_count > expected_limit
  end

  failure_message do
    "expected to exceed #{@expected_limit} queries, but only performed #{@actual_count}"
  end

  failure_message_when_negated do
    "expected not to exceed #{@expected_limit} queries, but performed #{@actual_count}"
  end

  def count_queries(&block)
    queries = []
    counter = ->(name, started, finished, unique_id, payload) {
      unless payload[:name] == "SCHEMA" || payload[:sql] =~ /^(BEGIN|COMMIT|SAVEPOINT|RELEASE)/
        queries << payload[:sql]
      end
    }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    queries.size
  end
end
