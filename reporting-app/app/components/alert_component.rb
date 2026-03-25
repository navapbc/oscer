# frozen_string_literal: true

# USWDS alert (usa-alert). Simple mode: message and optional heading, or use the body slot
# for lists, buttons, accordions.
class AlertComponent < ViewComponent::Base
  module TYPES
    INFO    = "info"
    SUCCESS = "success"
    WARNING = "warning"
    ERROR   = "error"

    ALL = [ INFO, SUCCESS, WARNING, ERROR ].freeze
  end

  module ROLES
    ALERT = "alert"
    STATUS = "status"

    ALL = [ ALERT, STATUS ].freeze
  end

  ROLE_DEFAULT = Object.new.freeze

  renders_one :body

  def initialize(type:, heading: nil, message: nil, heading_level: 2, classes: nil, style: nil, role: ROLE_DEFAULT)
    @type = type.to_s
    raise ArgumentError, "Invalid alert type: #{type.inspect}" unless TYPES::ALL.include?(@type)

    @heading = heading
    @message = message
    @heading_level = Integer(heading_level)
    raise ArgumentError, "heading_level must be between 1 and 6" unless (1..6).cover?(@heading_level)

    @classes = classes
    @style = style
    @role = role
  end

  attr_reader :type, :heading, :message, :heading_level, :classes, :style

  def alert_classes
    [ "usa-alert", "usa-alert--#{type}", classes ].compact.join(" ")
  end

  def error?
    type == TYPES::ERROR
  end

  def resolved_role
    if @role != ROLE_DEFAULT
      @role.presence
    else
      error? ? ROLES::ALERT : ROLES::STATUS
    end
  end
end
