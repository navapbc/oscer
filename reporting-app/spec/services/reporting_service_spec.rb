# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReportingService do
  let(:instance) { described_class.new }

  describe "time_to_close" do
    let(:caseworker) { create(:user, :as_caseworker) }

    it "returns 0 with no records" do
      expect(instance.time_to_close(7.days.ago)).to be_nil
    end

    it "returns time difference with one matching ActivityReportApplicationForm" do
      make_application_form_with_determination(:activity_report_application_form, 1.day)
      time_to_close = instance.time_to_close(7.days.ago)
      expect(time_to_close).to eq(1.day)
    end

    it "returns time difference with one matching ExemptionApplicationForm" do
      make_application_form_with_determination(:exemption_application_form, 1.day)
      time_to_close = instance.time_to_close(7.days.ago)
      expect(time_to_close).to eq(1.day)
    end

    it "returns average time difference with two matching ActivityReportApplicationForms" do
      make_application_form_with_determination(:activity_report_application_form, 1.day)
      make_application_form_with_determination(:activity_report_application_form, 2.day)
      time_to_close = instance.time_to_close(7.days.ago)
      expect(time_to_close).to eq(1.5.days)
    end

    it "returns average time difference with two matching ExemptionApplicationForms" do
      make_application_form_with_determination(:exemption_application_form, 1.day)
      make_application_form_with_determination(:exemption_application_form, 2.day)
      time_to_close = instance.time_to_close(7.days.ago)
      expect(time_to_close).to eq(1.5.days)
    end

    it "returns average time difference with matching ActivityReportApplicationForms and ExemptionApplicationForms" do
      make_application_form_with_determination(:activity_report_application_form, 1.day)
      make_application_form_with_determination(:exemption_application_form, 2.day)
      time_to_close = instance.time_to_close(7.days.ago)
      expect(time_to_close).to eq(1.5.days)
    end

    it "excludes records outside cutoff" do
      make_application_form_with_determination(:activity_report_application_form, 1.day)
      make_application_form_with_determination(:exemption_application_form, 2.day)
      time_to_close = instance.time_to_close(1.day.ago)
      expect(time_to_close).to be_nil
    end
  end

  def make_application_form_with_determination(form_type, time_delta)
    submission_date = 6.days.ago
    determination_date = submission_date + time_delta
    application_form = create(form_type, submitted_at: submission_date)
    certification = Certification.find(CertificationCase.find(application_form.certification_case_id).certification_id)
    determination = create(:determination, subject: certification, determined_at: determination_date, determined_by_id: caseworker.id)
  end
end
