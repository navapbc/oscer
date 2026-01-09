# frozen_string_literal: true

module ApplicationHelper
  def us_form_with(model: nil, scope: nil, url: nil, format: nil, **options, &block)
    options[:builder] = UswdsFormBuilder
    form_with model: model, scope: scope, url: url, format: format, **options, &block
  end

  def local_time(time, format: nil, timezone: "America/Chicago")
    I18n.l(time.in_time_zone(timezone), format: format)
  end

  def exemption_type_title(exemption_application_form)
    exemption_type = exemption_application_form.exemption_type
    return nil unless exemption_type

    # Try to get title from Exemption config, fallback to humanize
    Exemption.title_for(exemption_type) || exemption_type.humanize
  end
end
