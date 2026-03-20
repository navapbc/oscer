# frozen_string_literal: true

# USWDS alert (usa-alert). Simple mode: message and optional heading, or use the body slot
# for lists, buttons, accordions. Only type "error" sets role="alert". Optional style is
# forwarded to the root element (e.g. slim / no-icon layouts).
class AlertComponent < ViewComponent::Base
  TYPES = %w[info success warning error].freeze

  renders_one :body

  def initialize(type:, heading: nil, message: nil, heading_level: 2, classes: nil, style: nil)
    @type = type.to_s
    raise ArgumentError, "Invalid alert type: #{type.inspect}" unless TYPES.include?(@type)

    @heading = heading
    @message = message
    @heading_level = Integer(heading_level)
    raise ArgumentError, "heading_level must be between 1 and 6" unless (1..6).cover?(@heading_level)

    @classes = classes
    @style = style
  end

  attr_reader :type, :heading, :message, :heading_level, :classes, :style

  def alert_classes
    [ "usa-alert", "usa-alert--#{type}", classes ].compact.join(" ")
  end

  def error?
    type == "error"
  end
end
