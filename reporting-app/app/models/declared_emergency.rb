# frozen_string_literal: true

class DeclaredEmergency < ApplicationRecord
  DATE_FIELDS = %i[period_start period_end].freeze

  private attr_reader :force_update

  before_validation :calculate_origin_hash

  # Superseded and withdrawn declarations must never satisfy an exception, so
  # they are out of scope by default.
  default_scope { where(deleted_on: nil) }

  validates :fips_code, format: { with: /\A\d{3}\z/, message: "must be three digits" }
  # Skipped when unparsable, so the date error stands alone.
  validates :period_start, presence: true, unless: -> { unparsable_date?(:period_start) }
  validate :date_fields_are_dates
  # allow_nil matches Postgres, which treats NULLs as distinct in the partial
  # unique indexes backing these.
  validates :origin_id, uniqueness: { conditions: -> { where(deleted_on: nil) } }, allow_nil: true
  validates :origin_hash, uniqueness: { conditions: -> { where(deleted_on: nil) } }, allow_nil: true

  # stanza is one OpenFEMA disaster declaration; see the sample payload in
  # spec/models/declared_emergency_spec.rb for its full shape.
  def self.create_from_stanza(stanza)
    # A nil hash identifies nothing, so it must not match the nil-hash rows;
    # calculate_origin_hash derives one instead.
    return if stanza["hash"].present? && DeclaredEmergency.where(origin_hash: stanza["hash"]).exists?

    # Carry the report date across the supersede chain: it lives on soft deleted
    # rows, hence unscoped. maximum ignores nulls, so no filter is needed.
    reported_date = DeclaredEmergency.unscoped.where(origin_id: stanza["id"]).maximum(:reported_to_cms_on)

    begin
      DeclaredEmergency.transaction do
        declared_emergency = new
        declared_emergency.fips_code = stanza["fipsCountyCode"]
        declared_emergency.designated_area = stanza["designatedArea"]
        declared_emergency.declaration_title = stanza["declarationTitle"]
        # Snapped to month boundaries: compliance is evaluated per certifiable month,
        # so an emergency covering any part of a month covers the whole month.
        declared_emergency.period_start = month_boundary(stanza["incidentBeginDate"], :beginning_of_month)
        declared_emergency.period_end = month_boundary(stanza["incidentEndDate"], :end_of_month)
        declared_emergency.origin_id = stanza["id"]
        declared_emergency.origin_hash = stanza["hash"]
        declared_emergency.origin_raw = stanza
        declared_emergency.reported_to_cms_on = reported_date
        declared_emergency.delete_matching_emergencies
        declared_emergency.save!
        declared_emergency
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error(
        "DeclaredEmergency import failed for origin_id #{stanza['id'].inspect}: " \
        "#{e.record.errors.full_messages.join(', ')}"
      )
      nil
    end
  end

  def self.extend_end_date(old_declared_emergency, new_end_date)
    return unless old_declared_emergency.is_a?(DeclaredEmergency)
    # dup carries deleted_on across, so a deleted record would supersede itself
    # with a row that is already tombstoned.
    return if old_declared_emergency.deleted_on.present?

    begin
      DeclaredEmergency.transaction do
        declared_emergency = old_declared_emergency.dup
        declared_emergency.period_end = new_end_date
        declared_emergency.delete_matching_emergencies
        declared_emergency.save!
        declared_emergency
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error(
        "DeclaredEmergency end date extension failed for origin_id " \
        "#{old_declared_emergency.origin_id.inspect}: #{e.record.errors.full_messages.join(', ')}"
      )
      nil
    end
  end

  # Returns the raw value when it will not parse, so the assignment lands in
  # _before_type_cast and date_fields_are_dates can report it.
  def self.month_boundary(value, boundary)
    return value if value.blank?

    value.to_date.public_send(boundary)
  rescue Date::Error
    value
  end
  private_class_method :month_boundary

  def readonly?
    persisted? && !force_update
  end

  def mark_reported(date)
    return false if changed?

    @force_update = true
    update_attribute(:reported_to_cms_on, date)
  ensure
    @force_update = false
  end

  def soft_delete
    return false if changed?
    return true if deleted_on.present?

    @force_update = true
    update_attribute(:deleted_on, Date.current)
  ensure
    @force_update = false
  end

  # Nil origin_id is legal but identifies nothing, so it supersedes nothing.
  def delete_matching_emergencies
    return if origin_id.nil?

    DeclaredEmergency.where(origin_id: origin_id).each { |disaster| disaster.soft_delete }
  end

  private

  # ActiveRecord casts an unparsable date to nil, which would otherwise surface as
  # "can't be blank" on period_start and as a legitimately open-ended period on
  # period_end. Compare against the pre-cast value to tell the two apart.
  def unparsable_date?(field)
    public_send(field).nil? && public_send(:"#{field}_before_type_cast").present?
  end

  def date_fields_are_dates
    DATE_FIELDS.each do |field|
      errors.add(field, "is not a valid date") if unparsable_date?(field)
    end
  end

  def calculate_origin_hash
    return if !origin_raw.is_a?(Hash) || origin_raw.empty? || origin_hash.present?

    self.origin_hash = origin_raw["hash"].presence || Digest::SHA256.hexdigest(origin_raw.sort.to_json)
  end
end
