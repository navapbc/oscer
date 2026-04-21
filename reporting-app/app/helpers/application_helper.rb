# frozen_string_literal: true

module ApplicationHelper
  def us_form_with(model: false, scope: nil, url: nil, format: nil, **options, &block)
    options[:builder] = UswdsFormBuilder

    # Build arguments hash, excluding model if it's nil
    form_args = { scope: scope, url: url, format: format, **options }
    form_args[:model] = model if model

    form_with(**form_args, &block)
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

  # Renders a USWDS icon from the SVG sprite sheet.
  # When label is provided, the icon is meaningful (aria-label + title).
  # When label is nil, the icon is decorative (aria-hidden).
  def uswds_icon(icon_name, label: nil, size: 3, css_class: "", style: nil)
    classes = [ "usa-icon" ]
    classes << "usa-icon--size-#{size}" if size
    classes << css_class if css_class.present?

    aria_attrs = if label
                   { label: label }
    else
                   { hidden: true }
    end

    tag.svg(
      class: classes.join(" "),
      style: style,
      focusable: "false",
      role: "img",
      aria: aria_attrs
    ) do
      parts = []
      parts << tag.title(label) if label
      parts << tag.use("", "xlink:href" => "#{asset_path('@uswds/uswds/dist/img/sprite.svg')}##{icon_name}")
      safe_join(parts)
    end
  end
end
