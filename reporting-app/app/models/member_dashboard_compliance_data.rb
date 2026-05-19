# frozen_string_literal: true

# Read-side dashboard contract for OSCER-409: income/hours aggregates, report-status tokens,
# exemption flow + history, and privacy-safe income line items (no employer-identifying fields).
#
# +#480+ can render from +@member_dashboard_compliance+; legacy ivars on +DashboardController+
# stay in sync for existing partials.
#
# == Lazy fields
# +.build+ eagerly computes only what current dashboard partials read (hours, dates,
# report status, exemption flow state). Income aggregates, +member_income_rows+, and
# +exemption_history+ run their queries on first read, so members in +AWAITING_REPORT+
# (no view consumer yet) do not pay for them.
#
# == Attribute types
# - +report_status_token+ — +String+, one of +MemberStatus::DASHBOARD_REPORT_*+
# - +latest_determination+ — +Determination+ or +nil+. Combined CE consumers can read
#   +latest_determination.determination_data["satisfied_by"]+ for the
#   +Determination::CALCULATION_TYPE_EXTERNAL_CE_COMBINED+ split (hours / income / both / neither).
# - +show_income_summary+ — +Boolean+. **Always gate income reads on this**; income-scoped
#   attributes are +nil+ when false. Also false when +continuous_lookback_period+ is blank
#   (see +.build+).
# - +total_income+ / +target_income+ / +income_needed+ — +BigDecimal+ when
#   +show_income_summary+, else +nil+. Lazy.
# - +income_percent_of_requirement+ — +Float+ in 0.0..100.0 when +show_income_summary+, else +nil+. Lazy.
# - +total_hours_reported+ / +target_hours+ / +hours_needed+ — +Integer+ (hours rounded to the
#   nearest whole number at the read-model boundary via +Numeric#round+; see +.build+).
# - +period_start_on+ / +period_end_on+ — +Date+ or +nil+ (nil when income is hidden). Lazy.
# - +certification_date+ / +due_date+ — +Date+, sourced from +certification_requirements+.
# - +income_summary+ — +Hash+ matching the +IncomeComplianceDeterminationService+ shape, or +nil+
#   when income is hidden. Lazy.
# - +hours_summary+ — +Hash+ matching the +HoursComplianceDeterminationService+ shape.
# - +member_income_rows+ — +Array<MemberIncomeRow>+ (empty when income is hidden). Lazy.
# - +exemption_flow_state+ — +String+, one of the +EXEMPTION_*+ constants.
# - +exemption_history+ — +Array<ExemptionHistoryEntry>+ in reverse-chronological order
#   (exempt +Determination+ rows for the certification, plus in-flight exemption form rows). Lazy.
class MemberDashboardComplianceData
  EXEMPTION_NOT_STARTED = "not_started"
  EXEMPTION_DRAFT = "draft"
  EXEMPTION_PENDING_REVIEW = "pending_review"
  EXEMPTION_APPROVED = "approved"
  EXEMPTION_DENIED = "denied"

  MemberIncomeRow = Struct.new(
    :descriptor,
    :source_token,
    :activity_type_label,
    :amount,
    keyword_init: true
  )

  ExemptionHistoryEntry = Struct.new(
    :exemption_type_key,
    :exemption_type_label,
    :occurred_at,
    :status_token,
    keyword_init: true
  )

  attr_reader :report_status_token,
              :latest_determination,
              :show_income_summary,
              :total_hours_reported,
              :target_hours,
              :hours_needed,
              :certification_date,
              :due_date,
              :hours_summary,
              :exemption_flow_state

  class << self
    # Builds the dashboard read model.
    #
    # Hours aggregation runs unconditionally: the dashboard surfaces hours on both
    # income-based and hours-based screens (the design only varies which numbers are
    # foregrounded), so short-circuiting hours would force consumers to special-case
    # an extra branch. Income aggregation, +member_income_rows+, and +exemption_history+
    # are computed lazily on first access so pre-determination members don't pay for them.
    def build(certification:, certification_case:, exemption_application_form:, member_status:)
      latest = member_status.latest_determination
      lookback = certification.certification_requirements.continuous_lookback_period
      show_income = income_summary_visible?(latest, member_status) && lookback.present?

      external_hourly_rel = lookback.present? ? aggregator.fetch_external_hourly_activities(certification) : ExternalHourlyActivity.none
      # Pass only the external relation: +HoursComplianceDeterminationService+ will fetch and
      # +.reorder(nil)+ member rows internally so its +GROUP BY :category+ aggregation hits
      # the Postgres SUM path instead of erroring on the +ORDER BY+ on +member_hour_activities_for_certification+.
      hours_summary = HoursComplianceDeterminationService.aggregate_hours_for_certification(
        certification,
        certification_case: certification_case,
        external_hourly_activities: external_hourly_rel
      )

      target_hours = HoursComplianceDeterminationService::TARGET_HOURS
      # +Numeric#round+ to the nearest integer (not +.to_i+, which truncates toward zero), e.g.
      # 79.5 → 80 — keeps display parity with the staff side.
      total_hours = hours_summary[:total_hours].to_f.round

      new(
        certification: certification,
        certification_case: certification_case,
        exemption_application_form: exemption_application_form,
        member_status: member_status,
        lookback: lookback,
        report_status_token: member_status.dashboard_report_status,
        latest_determination: latest,
        show_income_summary: show_income,
        total_hours_reported: total_hours,
        target_hours: target_hours,
        hours_needed: [ target_hours - total_hours, 0 ].max,
        certification_date: certification.certification_requirements.certification_date,
        due_date: certification.certification_requirements.due_date,
        hours_summary: hours_summary,
        exemption_flow_state: exemption_flow_state(
          exemption_application_form: exemption_application_form,
          certification_case: certification_case,
          member_status: member_status
        )
      )
    end

    # Public class API for callers that only need the deterministic case tie-break (e.g.
    # +DashboardController#set_certification_case+) without including +ActivityAggregator+.
    # @param certification [Certification]
    # @param certification_case [CertificationCase, nil]
    # @return [CertificationCase, nil]
    def case_for_certification(certification, certification_case = nil)
      aggregator.certification_case_for_certification(certification, certification_case)
    end

    private

    # Singleton holder for +ActivityAggregator+ instance methods, scoped private so
    # +ActivityAggregator+'s 8 public methods do not become public class methods on
    # +MemberDashboardComplianceData+.
    def aggregator
      @aggregator ||= Object.new.extend(ActivityAggregator)
    end

    # Returns true when the dashboard should surface income summary cards.
    #
    # @note A +nil+ +ce_calculation_type+ (no determination yet) defaults to +true+:
    #   the pre-determination state assumes income reporting until product confirms an
    #   alternate intake. If product narrows this rule (e.g. "no determination ⇒ hide
    #   income"), update both this method and the
    #   +"when latest determination is hours_based"+ / +"when member status is exempt"+
    #   specs at +spec/read_models/member_dashboard_compliance_data_spec.rb+.
    def income_summary_visible?(latest_determination, member_status)
      return false if member_status.status == MemberStatus::EXEMPT

      ct = latest_determination&.ce_calculation_type
      return false if ct == Determination::CALCULATION_TYPE_HOURS_BASED

      ct.nil? ||
        ct == Determination::CALCULATION_TYPE_INCOME_BASED ||
        ct == Determination::CALCULATION_TYPE_EXTERNAL_CE_COMBINED
    end

    def exemption_flow_state(exemption_application_form:, certification_case:, member_status:)
      return EXEMPTION_APPROVED if member_status.status == MemberStatus::EXEMPT

      return EXEMPTION_NOT_STARTED if exemption_application_form.blank?

      if !exemption_application_form.submitted?
        return EXEMPTION_DRAFT
      end

      if certification_case&.exemption_request_approval_status == "approved"
        return EXEMPTION_APPROVED
      end

      if certification_case&.exemption_request_approval_status == "denied"
        return EXEMPTION_DENIED
      end

      # Submitted, no staff decision yet
      EXEMPTION_PENDING_REVIEW
    end
  end

  def initialize(certification:, certification_case:, exemption_application_form:, member_status:,
                 lookback:, report_status_token:, latest_determination:, show_income_summary:,
                 total_hours_reported:, target_hours:, hours_needed:,
                 certification_date:, due_date:, hours_summary:, exemption_flow_state:)
    @certification = certification
    @certification_case = certification_case
    @exemption_application_form = exemption_application_form
    @member_status = member_status
    @lookback = lookback
    @report_status_token = report_status_token
    @latest_determination = latest_determination
    @show_income_summary = show_income_summary
    @total_hours_reported = total_hours_reported
    @target_hours = target_hours
    @hours_needed = hours_needed
    @certification_date = certification_date
    @due_date = due_date
    @hours_summary = hours_summary
    @exemption_flow_state = exemption_flow_state
  end

  # @return [String, nil]
  def ce_calculation_type
    latest_determination&.ce_calculation_type
  end

  # --- Lazy income fields ---
  # All six readers return +nil+ when +show_income_summary+ is false; otherwise they share a
  # single memoized aggregation (one external + one member query, computed once).

  def income_summary
    income_data && income_data[:income_summary]
  end

  def total_income
    income_data && income_data[:total_income]
  end

  def target_income
    income_data && income_data[:target_income]
  end

  def income_needed
    income_data && income_data[:income_needed]
  end

  def income_percent_of_requirement
    income_data && income_data[:income_percent_of_requirement]
  end

  def period_start_on
    income_data && income_data[:period_start_on]
  end

  def period_end_on
    income_data && income_data[:period_end_on]
  end

  def member_income_rows
    return [] unless show_income_summary

    income_data[:member_income_rows]
  end

  # Lazy: queries +Determination+ + builds form-derived row only on first read. Reverse-chronological.
  def exemption_history
    @exemption_history ||= build_exemption_history
  end

  private

  def income_data
    return nil unless show_income_summary

    @income_data ||= build_income_data
  end

  def build_income_data
    external_income_rows = self.class.send(:aggregator)
      .fetch_external_income_activities(@certification, @lookback)
      .order(:period_start, :reported_at).to_a
    member_income_activity_rows = IncomeComplianceDeterminationService
      .member_income_activities_for_certification(@certification, certification_case: @certification_case).to_a

    income_summary = IncomeComplianceDeterminationService.aggregate_income_for_certification(
      @certification,
      certification_case: @certification_case,
      external_income_activities: external_income_rows,
      member_income_activity_rows: member_income_activity_rows
    )
    total_income = income_summary[:total_income].to_d
    target_income = IncomeComplianceDeterminationService::TARGET_INCOME_MONTHLY.to_d
    income_needed = [ target_income - total_income, BigDecimal("0") ].max

    {
      income_summary: income_summary,
      total_income: total_income,
      target_income: target_income,
      income_needed: income_needed,
      income_percent_of_requirement: percent_toward_requirement(total_income, target_income),
      member_income_rows: build_member_income_rows(external_income_rows, member_income_activity_rows),
      period_start_on: income_summary[:period_start],
      period_end_on: income_summary[:period_end]
    }
  end

  def percent_toward_requirement(total, target)
    return 0.0 if target.nil? || target <= 0

    raw = (total / target * 100).round(1).to_f
    [ [ raw, 0.0 ].max, 100.0 ].min
  end

  def build_member_income_rows(external_rows, income_activities)
    rows = []

    Array(external_rows).each do |row|
      cat = row.category.to_s.titleize
      rows << MemberIncomeRow.new(
        descriptor: I18n.t("dashboard.member_compliance.external_income_descriptor", category: cat),
        source_token: "external_ce",
        activity_type_label: cat,
        amount: BigDecimal(row.gross_income.to_s)
      )
    end

    Array(income_activities).each do |activity|
      cat = activity.category.to_s.titleize
      amt = activity.income.nil? ? BigDecimal("0") : BigDecimal(activity.income.dollar_amount.to_s)

      rows << MemberIncomeRow.new(
        descriptor: I18n.t("dashboard.member_compliance.self_reported_income_descriptor", category: cat),
        source_token: "self_reported",
        activity_type_label: cat,
        amount: amt
      )
    end

    rows
  end

  # Exempt-outcome determinations (automated eligibility and staff/form approvals) plus
  # in-flight exemption application rows when the case is not yet approved.
  def build_exemption_history
    entries = []

    determination_rows = Determination
      .unscope(:order)
      .where(subject_type: "Certification", subject_id: @certification.id)
      .where(outcome: :exempt)
      .order(determined_at: :desc, created_at: :desc)
      .to_a

    determination_rows.each do |det|
      type_key, label = exemption_history_type_for_determination(det)
      entries << ExemptionHistoryEntry.new(
        exemption_type_key: type_key,
        exemption_type_label: label,
        occurred_at: det.determined_at,
        status_token: EXEMPTION_APPROVED
      )
    end

    # Approved cases are already represented by the +Determination+ row above; the form-derived
    # row is only meaningful while the case is still draft, submitted-without-decision, or denied.
    # Comparing case state directly avoids brittle timestamp dedup between +submitted_at+ and
    # +determined_at+ when the two writes don't line up to the second.
    if @exemption_application_form.present? && @certification_case&.exemption_request_approval_status != "approved"
      hist_status = exemption_form_history_status(@certification_case, @exemption_application_form)
      if @exemption_application_form.exemption_type.present? && hist_status
        entries << ExemptionHistoryEntry.new(
          exemption_type_key: @exemption_application_form.exemption_type.to_s,
          exemption_type_label: exemption_type_label(@exemption_application_form.exemption_type),
          occurred_at: @exemption_application_form.submitted_at || @exemption_application_form.updated_at,
          status_token: hist_status
        )
      end
    end

    entries.sort_by { |e| e.occurred_at || Time.at(0) }.reverse
  end

  def exemption_form_history_status(certification_case, form)
    if !form.submitted?
      EXEMPTION_DRAFT
    elsif certification_case&.exemption_request_approval_status.nil?
      EXEMPTION_PENDING_REVIEW
    elsif certification_case&.exemption_request_approval_status == "denied"
      EXEMPTION_DENIED
    elsif certification_case&.exemption_request_approval_status == "approved"
      EXEMPTION_APPROVED
    end
  end

  def exemption_type_label(key)
    return I18n.t("dashboard.member_compliance.exemption_type_unknown") if key.blank?

    # +exemption_types.<key>+ stores a nested hash (+title+, +description+, ...); reach the leaf.
    I18n.t("exemption_types.#{key}.title", default: key.to_s.humanize)
  end

  def exemption_history_type_for_determination(det)
    type_key = exemption_type_key_from_determination_data(det.determination_data)
    return [ type_key, exemption_type_label(type_key) ] if type_key.present?

    exempt_reason = Array(det.reasons).find { |r| r.to_s.end_with?("_exempt") }
    if exempt_reason
      label = I18n.t(
        "services.member_status_service.reason_codes.#{exempt_reason}",
        default: exempt_reason.to_s.humanize
      )
      return [ exempt_reason, label ]
    end

    [ "exemption", I18n.t("dashboard.member_compliance.exemption_type_unknown") ]
  end

  # +Determination#determination_data+ is +jsonb+, so AR returns a +Hash+ (or nil).
  def exemption_type_key_from_determination_data(data)
    return nil if data.blank?

    data.stringify_keys["exemption_type"].presence
  end
end
