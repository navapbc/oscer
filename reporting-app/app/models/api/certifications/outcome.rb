# frozen_string_literal: true

class Api::Certifications::Outcome < ValueObject
  attribute :status, :string
  attribute :reason, :string
  attribute :source, :string
  attribute :timestamp, :datetime

  def self.from_certification(certification)
    determination = Determination.where(subject: certification).first
    return unless determination

    obj = Api::Certifications::Outcome.new
    if determination.not_compliant? && determination.automated?
        obj.status = "indeterminate"
        obj.reason =  ""
        obj.source =  ""
        obj.timestamp = determination.created_at
    elsif determination.not_compliant?
        obj.status = "not_compliant"
        obj.reason = ""
        obj.source = ""
        obj.timestamp = determination.created_at
    else
        obj.status = determination.outcome
        obj.reason = determination.reasons.first
        obj.source = determination.automated? ? "api" : "member"
        obj.timestamp = determination.created_at
    end
    obj
  end
end
