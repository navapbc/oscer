# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityReportApplicationForm, type: :model do
  describe "validations" do
    let(:certification) { create(:certification) }
    let(:certification_case) { create(:certification_case, certification: certification) }

    it "requires a certification_case_id" do
      form = build(:activity_report_application_form, certification_case_id: nil)

      expect(form.save).to be(false)
      expect(form.errors[:certification_case_id]).to include("can't be blank")
    end

    it "allows only one in-progress form per case" do
      create(:activity_report_application_form, certification_case_id: certification_case.id)
      second_form = build(:activity_report_application_form, certification_case_id: certification_case.id)

      expect(second_form.save).to be(false)
      expect(second_form.errors[:certification_case_id]).to include("has already been taken")
    end

    it "allows different certification_case_ids" do
      certification_case_2 = create(:certification_case)
      create(:activity_report_application_form, certification_case_id: certification_case.id)
      second_form = build(:activity_report_application_form, certification_case_id: certification_case_2.id)

      expect(second_form.save).to be(true)
    end

    context "with existing submitted form" do
      let!(:first_form) { create(:activity_report_application_form, :with_submitted_status, certification_case_id: certification_case.id) }

      it "does not allow a new form while the review task is still pending" do
        second_form = build(:activity_report_application_form, certification_case_id: certification_case.id)

        expect(second_form.save).to be(false)
        expect(second_form.errors[:certification_case_id]).to include("has already been taken")
      end

      context "with task on hold" do
        before { ReviewActivityReportTask.find_by(application_form: first_form).on_hold! }

        it "does not allow a new form" do
          second_form = build(:activity_report_application_form, certification_case_id: certification_case.id)

          expect(second_form.save).to be(false)
        end
      end

      context "with task completed" do
        before { ReviewActivityReportTask.find_by(application_form: first_form).completed! }

        it "allows a new form" do
          second_form = build(:activity_report_application_form, certification_case_id: certification_case.id)

          expect(second_form.save).to be(true)
        end

        it "allows multiple submitted forms for the same case" do
          second_form = create(:activity_report_application_form, certification_case_id: certification_case.id)

          expect(second_form.submit_application).to be(true)
        end
      end
    end

    context "when certification closed" do
      before { certification_case.close! }

      it "does not allow creation" do
        form = build(:activity_report_application_form, certification_case_id: certification_case.id)
        expect(form.save).to be(false)
      end
    end

    context "when verification window closed" do
      before { certification_case.update_attribute(:verification_window_end_date, 1.day.ago) }

      it "does not allow creation" do
        form = build(:activity_report_application_form, certification_case_id: certification_case.id)
        expect(form.save).to be(false)
      end
    end

    context "when verification window open" do
      before { certification_case.update_attribute(:verification_window_end_date, 1.day.from_now) }

      it "allows creation" do
        form = build(:activity_report_application_form, certification_case_id: certification_case.id)
        expect(form.save).to be(true)
      end
    end
  end

  describe "flow status" do
    let(:certification) { create(:certification) }
    let(:certification_case) { create(:certification_case, certification: certification) }

    before do
      allow(Strata::EventManager).to receive(:publish)
      allow(HoursComplianceDeterminationService).to receive(:aggregate_hours_for_certification).and_return({
        total_hours: 40,
        hours_by_category: { "education" => 40 },
        hours_by_source: { external: 30, activity: 10 },
        external_hourly_activity_ids: [ "ex-1" ],
        activity_ids: [ "act-1" ]
      })
    end

    context "without previous activity report" do
      it "returns 'in progress' when not submitted" do
        form = create(:activity_report_application_form, certification_case_id: certification_case.id)
        expect(form.flow_status).to eq "in_progress"
      end

      it "returns 'submitted' when no task" do
        form = create(:activity_report_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        expect(form.flow_status).to eq "submitted"
      end

      it "returns 'submitted' when task pending" do
        form = create(:activity_report_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        create(:review_activity_report_task, application_form: form, case: certification_case)
        expect(form.flow_status).to eq "submitted"
      end

      it "returns 'approved' when approved" do
        form = create(:activity_report_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        task = create(:review_activity_report_task, application_form: form, case: certification_case)
        task.completed!
        certification_case.accept_activity_report(nil, form)
        expect(form.flow_status).to eq "approved"
      end

      it "returns 'denied' when denied" do
        form = create(:activity_report_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        task = create(:review_activity_report_task, application_form: form, case: certification_case)
        task.completed!
        certification_case.deny_activity_report(nil, form)
        expect(form.flow_status).to eq "denied"
      end
    end

    context "with previous denied activity report" do
      before do
        previous_form = create(:activity_report_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        certification_case.deny_activity_report(nil, previous_form)
      end

      it "returns 'in progress' when not submitted" do
        form = create(:activity_report_application_form, certification_case_id: certification_case.id)
        expect(form.flow_status).to eq "in_progress"
      end

      it "returns 'submitted' when no task" do
        form = create(:activity_report_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        expect(form.flow_status).to eq "submitted"
      end

      it "returns 'submitted' when task pending" do
        form = create(:activity_report_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        create(:review_activity_report_task, application_form: form, case: certification_case)
        expect(form.flow_status).to eq "submitted"
      end

      it "returns 'approved' when approved" do
        form = create(:activity_report_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        task = create(:review_activity_report_task, application_form: form, case: certification_case)
        task.completed!
        certification_case.accept_activity_report(nil, form)
        expect(form.flow_status).to eq "approved"
      end

      it "returns 'denied' when denied" do
        form = create(:activity_report_application_form, :with_submitted_status, certification_case_id: certification_case.id)
        task = create(:review_activity_report_task, application_form: form, case: certification_case)
        task.completed!
        certification_case.deny_activity_report(nil, form)
        expect(form.flow_status).to eq "denied"
      end
    end
  end
end
