# frozen_string_literal: true

class Api::Certifications::Outcome < ValueObject
  attribute :status, :string
  attribute :reason, :string
  attribute :source, :string
  attribute :timestamp, :datetime

  def self.from_certification(certification)
    determination = Determination.where(subject: certification).latest_first.first
    return unless determination

    obj = new(timestamp: determination.created_at)
    if determination.not_compliant? && determination.automated?
      obj.status = "indeterminate"
    elsif determination.not_compliant?
      obj.status = "not_compliant"
    else
      obj.status = determination.outcome
      obj.reason = determination.reasons.first
      obj.source = determination.automated? ? "api" : "member"
    end
    obj
  end
end
