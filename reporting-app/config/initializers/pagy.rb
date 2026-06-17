# frozen_string_literal: true

# Pagy pagination configuration.
# See https://ddnexus.github.io/pagy/

# Default number of records per page across paginated index pages.
Pagy::OPTIONS[:limit] = 25

# Page-number slots in the series. First/last anchoring and :gap (ellipsis) markers
# kick in once the page count exceeds the slot count; 7 matches Pagy's own default.
Pagy::OPTIONS[:slots] = 7

# Out-of-range ?page= values (e.g. ?page=99999) render an empty page rather than
# raising: Pagy v43 leaves :raise_range_error unset by default, and reports the last
# real page via @pagy.previous so the pager still links back into range.

Pagy::OPTIONS.freeze

# USWDS-styled pagination nav for Pagy v43.
#
# Pagy ships Bootstrap/Bulma/Tailwind styles, not USWDS, so we register a custom
# `:uswds` style. `pagy.series_nav(:uswds, ...)` dispatches here by convention
# (`series_nav(style)` calls `#{style}_series_nav`). See:
# https://designsystem.digital.gov/components/pagination/
#
# This runs in the Pagy instance context, which has no ActionView helpers, so:
# - page hrefs come from Pagy's own #page_url,
# - text comes from ::I18n.translate (fully qualified: a bare `I18n` here resolves
#   lexically to Pagy::I18n, Pagy's own dictionary, not the Rails app's locales),
# - the prev/next chevron <svg> icons are rendered by the view via uswds_icon
#   (which needs asset_path) and passed in through :prev_icon / :next_icon.
#
# #series is Pagy's protected method (one entry per slot: Integer -> a linkable
# page, String -> the current page, :gap -> an ellipsis); it is reachable here
# because this method lives on the same Pagy instance.
class Pagy
  module NumericHelpers
    private

    def uswds_series_nav(prev_icon:, next_icon:, **opts)
      items = series(**opts).map { |item| uswds_page_item(item) }
      items.unshift(uswds_arrow_item(:previous, prev_icon)) if @previous
      items.push(uswds_arrow_item(:next, next_icon)) if @next

      # Marked html_safe here (app-owned markup); the view call site stays clean.
      nav = %(<nav aria-label="#{::I18n.translate('pagination.aria_label')}" class="usa-pagination">) +
        %(<ul class="usa-pagination__list">#{items.join}</ul></nav>)
      nav.html_safe
    end

    # One <li> per series entry: an Integer is a linkable page, a String is the
    # current page (gets usa-current + aria-current), and :gap is an ellipsis.
    def uswds_page_item(item)
      if item == :gap
        return %(<li class="usa-pagination__item usa-pagination__overflow" role="presentation"><span>&hellip;</span></li>)
      end

      current = item.is_a?(String)
      button_class = current ? "usa-pagination__button usa-current" : "usa-pagination__button"
      aria_current = current ? %( aria-current="page") : ""
      %(<li class="usa-pagination__item usa-pagination__page-no">) +
        %(<a href="#{page_url(item)}" class="#{button_class}" ) +
        %(aria-label="#{::I18n.translate('pagination.page', number: item)}"#{aria_current}>#{item}</a></li>)
    end

    # The previous/next arrow <li>. The chevron <svg> is rendered by the view
    # (where asset_path lives) and passed in; the icon sits before the label for
    # :previous and after it for :next, per USWDS.
    def uswds_arrow_item(direction, icon)
      page  = direction == :previous ? @previous : @next
      label = ::I18n.translate("pagination.#{direction}")
      text  = %(<span class="usa-pagination__link-text">#{label}</span>)
      inner = direction == :previous ? "#{icon}#{text}" : "#{text}#{icon}"
      %(<li class="usa-pagination__item usa-pagination__arrow">) +
        %(<a href="#{page_url(page)}" class="usa-pagination__link usa-pagination__#{direction}-page" aria-label="#{label}">#{inner}</a></li>)
    end
  end
end
