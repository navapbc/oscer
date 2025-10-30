# frozen_string_literal: true

module ApplicationHelper
  def us_form_with(model: nil, scope: nil, url: nil, format: nil, **options, &block)
    options[:builder] = UswdsFormBuilder
    form_with model: model, scope: scope, url: url, format: format, **options, &block
  end

  def local_time(time, format: nil, timezone: "America/Chicago")
    I18n.l(time.in_time_zone(timezone), format: format)
  end
end
