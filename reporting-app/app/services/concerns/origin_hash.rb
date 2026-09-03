# frozen_string_literal: true

# Fingerprints the values that identify one external activity submission.
# The hash is computed before a submission is split into monthly entries and stored on
# each of them, so a resubmission of the same source activity is skipped as a whole.
module OriginHash
  # Well beyond the scale of the hours and gross_income columns; enough for any
  # Rational a caller derives from a date range.
  NUMERIC_PRECISION = 16

  # Values are normalized first, so equivalent inputs (decimal scale, numeric or date
  # class, name casing and padding) produce the same digest.
  def origin_hash_for(*values)
    Digest::SHA256.hexdigest(values.map { |value| normalize_origin_value(value) }.join("|"))
  end

  # The reported name stays out of the log: it can be a person's name, and logs carry no PII.
  def log_duplicate_submission(origin_hash, member_id:, category:, period_start:, period_end:)
    Rails.logger.warn(
      "#{self}: skipped duplicate submission for member_id=#{member_id} " \
      "category=#{category} period=#{period_start}..#{period_end} origin_hash=#{origin_hash}"
    )
  end

  private

  def normalize_origin_value(value)
    case value
    when nil then ""
    when Numeric then BigDecimal(value, NUMERIC_PRECISION).to_s
    when Date, Time then value.to_date.iso8601
    else value.to_s.strip.downcase
    end
  end
end
