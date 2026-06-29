# frozen_string_literal: true

# Value object for the OSCER-409 member dashboard projection. Built by
# +MemberDashboardComplianceService.build+; sibling to +MemberStatus+ (which is the
# determination-driven status this projection wraps).
#
# == Lazy fields
# Income aggregates, +member_income_rows+, and +exemption_history+ run their queries on
# first read, not at construction. This keeps the +AWAITING_REPORT+ dashboard path off the
# income aggregation until a view consumer reads those fields (OSCER-480). The instance
# therefore holds AR refs (+@certification+, +@certification_case+, +@lookback+,
# +@exemption_application_form+) so its lazy readers can run.
#
# == Attribute types
# - +report_status_token+ — +String+, one of +MemberStatus::DASHBOARD_REPORT_*+
# - +latest_determination+ — +Determination+ or +nil+. Combined CE consumers can read
#   +latest_determination.determination_data["satisfied_by"]+ for the
#   +Determination::CALCULATION_TYPE_EXTERNAL_CE_COMBINED+ split (hours / income / both / neither).
# - +show_income_summary+ — +Boolean+. **Always gate income reads on this**; income-scoped
#   attributes are +nil+ when false. Also false when +continuous_lookback_period+ is blank.
# - +total_income+ / +target_income+ / +income_needed+ — +BigDecimal+ when
#   +show_income_summary+, else +nil+. Lazy.
# - +income_percent_of_requirement+ — +Float+ in 0.0..100.0 when +show_income_summary+, else +nil+. Lazy.
# - +total_hours_reported+ / +target_hours+ / +hours_needed+ — +Integer+.
# - +period_start_on+ / +period_end_on+ — +Date+ or +nil+ (nil when income is hidden). Lazy.
# - +certification_date+ / +due_date+ — +Date+, sourced from +certification_requirements+.
# - +income_summary+ — +Hash+ matching the +IncomeComplianceDeterminationService+ shape, or +nil+
#   when income is hidden. Lazy.
# - +hours_summary+ — +Hash+ matching the +HoursComplianceDeterminationService+ shape.
# - +member_income_rows+ — +Array<MemberIncomeRow>+ (empty when income is hidden). Lazy.
# - +certification+ / +certification_case+ — aggregate refs for dashboard links and lazy income/history.
# - +exemption_flow_state+ — +String+, one of the +EXEMPTION_*+ constants.
# - +exemption_history+ — +Array<ExemptionHistoryEntry>+ in reverse-chronological order. Lazy.
class MemberDashboardCompliance
  EXEMPTION_NOT_STARTED = "not_started"
  EXEMPTION_DRAFT = "draft"
  EXEMPTION_PENDING_REVIEW = "pending_review"
  EXEMPTION_APPROVED = "approved"
  EXEMPTION_DENIED = "denied"

  # Source tokens for the activity tables (mapped to display labels by
  # +MemberComplianceHelper#member_compliance_source_label+).
  SOURCE_EXTERNAL_CE = "external_ce"
  SOURCE_SELF_REPORTED = "self_reported"

  MemberIncomeRow = Struct.new(
    :descriptor,
    :source_token,
    :activity_type_label,
    :amount,
    keyword_init: true
  )

  # Rows for the data-driven activity tables (OSCER-642). Distinct from +MemberIncomeRow+
  # (which powers the income progress cards and is gated on +show_income_summary+): these
  # carry an +organization_name+ column to match the staff case-view tables and are built
  # ungated so the dashboard mirrors staff "show whatever was reported" behavior.
  HourTableRow = Struct.new(
    :organization_name,
    :source_token,
    :activity_type_label,
    :hours,
    keyword_init: true
  )

  IncomeTableRow = Struct.new(
    :organization_name,
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

  attr_reader :certification,
              :certification_case,
              :report_status_token,
              :latest_determination,
              :show_income_summary,
              :activity_report_application_form,
              :exemption_application_form,
              :total_hours_reported,
              :target_hours,
              :hours_needed,
              :certification_date,
              :due_date,
              :hours_summary,
              :exemption_flow_state

  def initialize(certification:, certification_case:, exemption_application_form:, activity_report_application_form:,
                 lookback:, report_status_token:, latest_determination:, show_income_summary:,
                 total_hours_reported:, target_hours:, hours_needed:,
                 certification_date:, due_date:, hours_summary:, exemption_flow_state:)
    @certification = certification
    @certification_case = certification_case
    @activity_report_application_form = activity_report_application_form
    @exemption_application_form = exemption_application_form
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

  # Display mode for the current-period compliance summary partial
  # (+dashboard/_compliance_status+). Derived from +show_income_summary+ and
  # +ce_calculation_type+ so the view switches on a single intent-revealing token
  # instead of re-deriving the determination semantics inline.
  #
  # - +:hours_only+ — hours-based CE (or income hidden / pre-build legacy path): hours block only.
  # - +:income_only+ — income-based CE: income block only (hours omitted, OSCER-716).
  # - +:combined+ — combined CE, satisfied by hours OR income (also the pre-determination
  #   default, where +ce_calculation_type+ is +nil+ but income is assumed visible).
  #
  # @return [Symbol] one of +:hours_only+, +:income_only+, +:combined+
  def compliance_summary_mode
    return :hours_only unless show_income_summary
    return :income_only if ce_calculation_type == Determination::CALCULATION_TYPE_INCOME_BASED

    :combined
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

  # --- Data-driven activity tables (OSCER-642) ---
  # Ungated, lazy mirrors of the staff case view: tables surface whatever activity the
  # member actually reported (hours, income, or both), regardless of +show_income_summary+
  # (which stays scoped to the progress cards in #643). Each runs its queries on first read,
  # so the get-started / exemption / awaiting-report paths never trigger them.

  def hours_has_data?
    hour_table_rows.any?
  end

  def income_has_data?
    income_table_rows.any?
  end

  # @return [Array<HourTableRow>]
  def hour_table_rows
    @hour_table_rows ||= build_hour_table_rows
  end

  # @return [Array<IncomeTableRow>]
  def income_table_rows
    @income_table_rows ||= build_income_table_rows
  end

  # Footer total for the hours table. Sums displayed rows so the footer matches visible data.
  def hour_table_total
    hour_table_rows.sum(0) { |row| row.hours || 0 }
  end

  # Footer totals for the income table. Independent of the gated +total_income+ card reader.
  def income_table_total
    income_table_rows.sum(BigDecimal("0")) { |row| row.amount || BigDecimal("0") }
  end

  def income_table_target
    IncomeComplianceDeterminationService::TARGET_INCOME_MONTHLY.to_d
  end

  def income_table_additional_needed
    [ income_table_target - income_table_total, BigDecimal("0") ].max
  end

  # --- Activity line items (OSCER-690) ---
  # Every activity report form on the case, newest first, for the per-submission line-item
  # tables. Mirrors the staff case-view ordering (+created_at: :desc+). Lazy: queried on first
  # read, so dashboard paths that don't render line items never trigger it. Activities and their
  # supporting-document attachments are eager-loaded via the form's +default_scope+ and
  # +Activity+'s +with_attached_supporting_documents+ scope, so iterating rows + documents in the
  # view stays N+1-free.
  #
  # @return [Array<ActivityReportApplicationForm>]
  def activity_reports_for_line_items
    @activity_reports_for_line_items ||= build_activity_reports_for_line_items
  end

  # True when at least one form on the case has activities — the line-items render gate. A form
  # with no activities (e.g. a freshly created in-progress report) contributes no line items.
  # Uses a lightweight existence check; the full eager-loaded query runs only when rendering.
  def activity_line_items?
    return @activity_line_items_present if defined?(@activity_line_items_present)

    @activity_line_items_present = activity_line_items_exist?
  end

  private

  def activity_line_items_exist?
    return false if @certification_case.blank?

    ActivityReportApplicationForm
      .where(certification_case_id: @certification_case.id)
      .joins(:activities)
      .exists?
  end

  def build_activity_reports_for_line_items
    return [] if @certification_case.blank?

    # +ActivityReportApplicationForm+'s default scope already eager-loads +:activities+, but the
    # per-activity supporting-document attachments are not chained through it. Eager-load the
    # attachment blobs explicitly so the line-item view renders every form's documents N+1-free.
    ActivityReportApplicationForm
      .where(certification_case_id: @certification_case.id)
      .order(created_at: :desc)
      .includes(activities: { supporting_documents_attachments: :blob })
      .to_a
  end

  def income_data
    return nil unless show_income_summary

    @income_data ||= build_income_data
  end

  def build_income_data
    external_income_rows = ExternalIncomeActivity
      .for_member(@certification.member_id)
      .within_period(@lookback)
      .order(:period_start, :reported_at).to_a
    member_income_activity_rows = IncomeComplianceDeterminationService
                                    .member_income_activities_for_certification(@certification,
                                                                                application_form: @activity_report_application_form).to_a

    income_summary = IncomeComplianceDeterminationService.aggregate_income_for_certification(
      @certification,
      application_form: @activity_report_application_form,
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

  # Mirrors the staff hours table: external (state-provided) rows first, then member
  # self-reported activity rows. +ExternalHourlyActivity+ has no employer metadata, so the
  # organization name falls back to "<Category> Activity".
  def build_hour_table_rows
    external_rows = external_hourly_activities
    member_rows = HoursComplianceDeterminationService
      .member_hour_activities_for_certification(@certification, application_form: @activity_report_application_form)
      .to_a

    rows = external_rows.map do |row|
      cat = row.category.to_s.titleize
      HourTableRow.new(
        organization_name: external_activity_org_name(cat),
        source_token: SOURCE_EXTERNAL_CE,
        activity_type_label: cat,
        hours: row.hours
      )
    end

    rows + member_rows.map do |activity|
      HourTableRow.new(
        organization_name: activity.name,
        source_token: SOURCE_SELF_REPORTED,
        activity_type_label: activity.category.to_s.titleize,
        hours: activity.read_attribute(:hours)
      )
    end
  end

  # Mirrors the staff income table. Unlike the gated +build_member_income_rows+ (cards), the
  # organization column shows employer metadata / activity name to match staff column semantics.
  def build_income_table_rows
    external_rows = external_income_activities
    member_rows = IncomeComplianceDeterminationService
      .member_income_activities_for_certification(@certification, application_form: @activity_report_application_form)
      .to_a

    rows = external_rows.map do |row|
      cat = row.category.to_s.titleize
      IncomeTableRow.new(
        organization_name: organization_name_for_external_income(row, cat),
        source_token: SOURCE_EXTERNAL_CE,
        activity_type_label: cat,
        amount: BigDecimal(row.gross_income.to_s)
      )
    end

    rows + member_rows.map do |activity|
      IncomeTableRow.new(
        organization_name: activity.name,
        source_token: SOURCE_SELF_REPORTED,
        activity_type_label: activity.category.to_s.titleize,
        amount: activity.income.nil? ? nil : BigDecimal(activity.income.dollar_amount.to_s)
      )
    end
  end

  def external_hourly_activities
    return [] if @lookback.blank?

    ExternalHourlyActivity
      .for_member(@certification.member_id)
      .within_period(@lookback)
      .order(:period_start, :created_at)
      .to_a
  end

  def external_income_activities
    return [] if @lookback.blank?

    ExternalIncomeActivity
      .for_member(@certification.member_id)
      .within_period(@lookback)
      .order(:period_start, :reported_at)
      .to_a
  end

  def external_activity_org_name(category_name)
    "#{category_name} #{I18n.t('certification_cases.common.activity_label')}"
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
        source_token: SOURCE_EXTERNAL_CE,
        activity_type_label: cat,
        amount: BigDecimal(row.gross_income.to_s)
      )
    end

    Array(income_activities).each do |activity|
      cat = activity.category.to_s.titleize
      amt = activity.income.nil? ? BigDecimal("0") : BigDecimal(activity.income.dollar_amount.to_s)

      rows << MemberIncomeRow.new(
        descriptor: I18n.t("dashboard.member_compliance.self_reported_income_descriptor", category: cat),
        source_token: SOURCE_SELF_REPORTED,
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
    elsif !form.staff_exemption_review_complete?
      EXEMPTION_PENDING_REVIEW
    elsif certification_case&.exemption_request_approval_status == "denied"
      EXEMPTION_DENIED
    elsif certification_case&.exemption_request_approval_status == "approved"
      EXEMPTION_APPROVED
    else
      EXEMPTION_PENDING_REVIEW
    end
  end

  def exemption_type_label(key)
    return I18n.t("dashboard.member_compliance.exemption_type_unknown") if key.blank?

    # +exemption_types.<key>+ stores a nested hash (+title+, +description+, ...); reach the leaf.
    I18n.t("exemption_types.#{key}.title", default: key.to_s.humanize)
  end

  # The exemption type lives in different places depending on how the exemption was decided.
  # Automated (eligibility-derived) exemptions encode the type in their reason codes, while
  # manual (staff-reviewed) exemptions record the member's claimed type in
  # +determination_data["exemption_type"]+. Branch on +decision_method+ so each reads its
  # authoritative source — this also keeps a legacy/malformed +determination_data+ on an
  # automated row from ever reaching the Hash read (see #680).
  def exemption_history_type_for_determination(det)
    if det.decision_method == "automated"
      # The row is already +outcome: :exempt+, so its reasons are exemption reasons; the
      # reason code is the type. No need to inspect determination_data.
      reason = Array(det.reasons).first
      reason ? [ reason, exemption_reason_label(reason) ] : unknown_exemption_type
    else
      label_from_determination_data(det.determination_data) || unknown_exemption_type
    end
  end

  # Manual (staff-reviewed) exemptions record the member's claimed type on the determination.
  # Returns +nil+ (so the caller falls back) when no usable type is present. Guards the shape:
  # +determination_data+ is +jsonb+ and should be a Hash, but a malformed row must not raise.
  def label_from_determination_data(data)
    return nil unless data.is_a?(Hash)

    key = data.stringify_keys["exemption_type"].presence
    key && [ key, exemption_type_label(key) ]
  end

  def exemption_reason_label(reason)
    I18n.t(
      "services.member_status_service.reason_codes.#{reason}",
      default: reason.to_s.humanize
    )
  end

  def unknown_exemption_type
    [ "exemption", I18n.t("dashboard.member_compliance.exemption_type_unknown") ]
  end

  # Mirrors the staff +certification_cases/_income_reported_table+ organization column:
  # employer metadata when present, otherwise "<Category> Activity".
  def organization_name_for_external_income(row, category_name)
    row.metadata&.dig("employer").presence || external_activity_org_name(category_name)
  end
end
