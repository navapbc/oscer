# frozen_string_literal: true

require "rails_helper"

# OscerApplicationForm is the abstract base (no table of its own) that holds the case-bound
# lifecycle shared by its three concrete subclasses. Its behavior is therefore exercised through
# those subclasses. These specs assert the SHARED contract holds identically across all three —
# the parity the consolidation guarantees — and, critically, they exercise the paths where the
# base dereferences the per-subclass bindings: has_pending_form's review-task branch
# (review_task_class) and flow_status (case_approval_status_accessor). The exhaustive per-model
# behavior (full flow_status matrix, model-specific fields) stays in each subclass's own spec.

# Defined as a local (not a constant) so it does not leak onto Object; the example-group blocks
# below close over it at definition time.
subclasses = [
  {
    name: "ActivityReportApplicationForm",
    model: ActivityReportApplicationForm,
    factory: :activity_report_application_form,
    review_task_class: ReviewActivityReportTask,
    review_task_factory: :review_activity_report_task,
    case_approval_status_accessor: :activity_report_approval_status,
    approve: ->(kase, form) { kase.accept_activity_report(nil, form) }
  },
  {
    name: "ExemptionApplicationForm",
    model: ExemptionApplicationForm,
    factory: :exemption_application_form,
    review_task_class: ReviewExemptionClaimTask,
    review_task_factory: :review_exemption_claim_task,
    case_approval_status_accessor: :exemption_request_approval_status,
    approve: ->(kase, form) { kase.accept_exemption_request(nil, form) }
  },
  {
    name: "DenialResponseApplicationForm",
    model: DenialResponseApplicationForm,
    factory: :denial_response_application_form,
    review_task_class: ReviewDenialResponseTask,
    review_task_factory: :review_denial_response_task,
    case_approval_status_accessor: :denial_response_approval_status,
    approve: ->(kase, form) { kase.accept_denial_response(nil, form) }
  }
].freeze

RSpec.describe OscerApplicationForm, type: :model do
  it "is an abstract class layered directly under Strata::ApplicationForm" do
    expect(described_class.abstract_class?).to be(true)
    expect(described_class.superclass).to eq(Strata::ApplicationForm)
  end

  it "includes the FormApprovalStatus concern for all subclasses" do
    subclasses.each do |subclass|
      expect(subclass[:model].new).to respond_to(:approval_status, :approved?, :denied?)
    end
  end

  describe "per-subclass bindings (contract)" do
    subclasses.each do |subclass|
      context subclass[:name] do
        it "descends from the abstract base" do
          expect(subclass[:model].ancestors).to include(described_class)
        end

        it "binds its review-task class" do
          expect(subclass[:model].review_task_class).to eq(subclass[:review_task_class])
        end

        it "binds its case approval-status accessor" do
          expect(subclass[:model].case_approval_status_accessor).to eq(subclass[:case_approval_status_accessor])
        end
      end
    end
  end

  describe "binding enforcement (fail loud)" do
    # A subclass that omits a required binding must fail loudly the moment its lifecycle is
    # exercised, rather than silently misbehaving. An anonymous subclass declares neither binding.
    let(:unconfigured_subclass) { Class.new(described_class) }

    it "raises a descriptive error when the review-task class is not declared" do
      expect { unconfigured_subclass.review_task_class }
        .to raise_error(NotImplementedError, /has_review_task/)
    end

    it "raises a descriptive error when the case approval-status accessor is not declared" do
      expect { unconfigured_subclass.case_approval_status_accessor }
        .to raise_error(NotImplementedError, /case_approval_status/)
    end
  end

  describe "shared lifecycle (parity across all subclasses)" do
    let(:certification) { create(:certification) }
    let(:certification_case) { create(:certification_case, certification: certification) }

    before { allow(Strata::EventManager).to receive(:publish) }

    subclasses.each do |subclass|
      context subclass[:name] do
        # NOTE: exemption gains this presence validation via the base (parity addition — it had
        # none before). Its own spec never built a nil-case form, so the regression net stays green.
        it "requires a certification_case_id" do
          form = build(subclass[:factory], certification_case_id: nil)

          expect(form.save).to be(false)
          expect(form.errors[:certification_case_id]).to include("can't be blank")
        end

        it "rejects a nonexistent certification case" do
          form = build(subclass[:factory], certification_case_id: SecureRandom.uuid)

          expect(form.save).to be(false)
          expect(form.errors[:certification_case_id]).to include("is invalid")
        end

        it "rejects creation once the case is closed" do
          certification_case.close!
          form = build(subclass[:factory], certification_case_id: certification_case.id)

          expect(form.save).to be(false)
          expect(form.errors[:certification_case_id]).to include("has closed")
        end

        it "rejects creation once the verification window has ended" do
          certification_case.update_attribute(:verification_window_end_date, 1.day.ago)
          form = build(subclass[:factory], certification_case_id: certification_case.id)

          expect(form.save).to be(false)
          expect(form.errors[:certification_case_id]).to include("verification window has ended")
        end

        it "allows only one in-progress form per case" do
          create(subclass[:factory], certification_case_id: certification_case.id)
          second_form = build(subclass[:factory], certification_case_id: certification_case.id)

          expect(second_form.save).to be(false)
          expect(second_form.errors[:certification_case_id]).to include("has already been taken")
        end

        # The base override must preserve super's payload (application_form_id, submitted_at) — those
        # keys route the Created/Submitted events to the business process. Asserting only case_id
        # would pass even if a base impl dropped super, silently breaking event routing.
        it "merges the case id into the event payload without dropping super's keys" do
          form = create(subclass[:factory], :with_submitted_status, certification_case_id: certification_case.id)

          expect(form.send(:event_payload)).to include(
            application_form_id: form.id,
            submitted_at: form.submitted_at,
            case_id: certification_case.id
          )
        end

        describe ".has_pending_form" do
          it "is false when the case has no forms" do
            expect(subclass[:model].has_pending_form(certification_case.id)).to be(false)
          end

          it "is true while an in-progress form exists" do
            create(subclass[:factory], certification_case_id: certification_case.id)

            expect(subclass[:model].has_pending_form(certification_case.id)).to be(true)
          end

          # Exercises the base's review-task branch (dereferences review_task_class): a submitted
          # form is no longer in-progress, so only a pending review task keeps the case blocked.
          it "is true while a submitted form's review task is still pending" do
            form = create(subclass[:factory], :with_submitted_status, certification_case_id: certification_case.id)
            create(subclass[:review_task_factory], application_form: form, case: certification_case)

            expect(subclass[:model].has_pending_form(certification_case.id)).to be(true)
          end
        end

        # Exercises the base's flow_status resolution through case_approval_status_accessor once the
        # review task is complete and the case has recorded an outcome. The full approved/denied
        # matrix stays in each subclass spec; one outcome here pins the accessor dereference.
        it "resolves flow_status to the case outcome once its review task completes" do
          form = create(subclass[:factory], :with_submitted_status, certification_case_id: certification_case.id)
          task = create(subclass[:review_task_factory], application_form: form, case: certification_case)
          task.completed!
          subclass[:approve].call(certification_case, form)

          expect(form.flow_status).to eq("approved")
        end
      end
    end
  end

  # Exemption keeps this as a public delegator: it has external callers (member_dashboard_compliance,
  # member_dashboard_compliance_service) and must survive the consolidation intact.
  describe "ExemptionApplicationForm#staff_exemption_review_complete?" do
    let(:certification_case) { create(:certification_case) }

    before { allow(Strata::EventManager).to receive(:publish) }

    it "is false before the review task completes and true after" do
      form = create(:exemption_application_form, :with_submitted_status, certification_case_id: certification_case.id)
      task = create(:review_exemption_claim_task, application_form: form, case: certification_case)

      expect(form.staff_exemption_review_complete?).to be(false)

      task.completed!
      expect(form.reload.staff_exemption_review_complete?).to be(true)
    end
  end
end
