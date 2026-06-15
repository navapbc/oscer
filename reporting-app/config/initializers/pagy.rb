# frozen_string_literal: true

# Pagy pagination configuration.
# See https://ddnexus.github.io/pagy/

# Gracefully clamp out-of-range ?page= values (e.g. ?page=99999) to the last page
# instead of raising Pagy::OverflowError.
require "pagy/extras/overflow"

# Default number of records per page across paginated index pages.
Pagy::DEFAULT[:limit] = 25
Pagy::DEFAULT[:overflow] = :last_page
