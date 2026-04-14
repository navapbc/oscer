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
      submission_date = 6.days.ago
      determination_date = submission_date + 1.day
      application_form = create(:activity_report_application_form, submitted_at: submission_date)
      determination = create(:determination, subject: application_form.certification, determined_at: determination_date, determined_by_id: caseworker.id)
      time_to_close = instance.time_to_close(7.days.ago)
      expect(time_to_close).to eq(1.day)
    end

    it "returns time difference with one matching ExemptionApplicationForm" do
      submission_date = 6.days.ago
      determination_date = submission_date + 1.day
      application_form = create(:exemption_application_form, submitted_at: submission_date)
      certification = Certification.find(CertificationCase.find(application_form.certification_case_id).certification_id)
      determination = create(:determination, subject: certification, determined_at: determination_date, determined_by_id: caseworker.id)
      time_to_close = instance.time_to_close(7.days.ago)
      expect(time_to_close).to eq(1.day)
    end

    it "returns average time difference with two matching ActivityReportApplicationForms" do
      submission_date = 6.days.ago
      2.times do |count|
        application_form = create(:activity_report_application_form, submitted_at: submission_date + count.days)
        determination_date = submission_date + 2.days
        determination = create(:determination, subject: application_form.certification, determined_at: determination_date, determined_by_id: caseworker.id)
      end
      time_to_close = instance.time_to_close(7.days.ago)
      expect(time_to_close).to eq(1.5.day)
    end

    it "returns average time difference with two matching ExemptionApplicationForms" do
      submission_date = 6.days.ago
      2.times do |count|
        application_form = create(:exemption_application_form, submitted_at: submission_date + count.days)
        determination_date = submission_date + 2.days
        certification = Certification.find(CertificationCase.find(application_form.certification_case_id).certification_id)
        determination = create(:determination, subject: certification, determined_at: determination_date, determined_by_id: caseworker.id)
      end
      time_to_close = instance.time_to_close(7.days.ago)
      expect(time_to_close).to eq(1.5.day)
    end

    it "returns average time difference with matching ActivityReportApplicationForms and ExemptionApplicationForms" do
      submission_date = 6.days.ago
      activity_report_application_form = create(:activity_report_application_form, submitted_at: submission_date)
      create(:determination, subject: activity_report_application_form.certification, determined_at: submission_date + 1.day, determined_by_id: caseworker.id)
      exemption_application_form = create(:exemption_application_form, submitted_at: submission_date)
      certification = Certification.find(CertificationCase.find(exemption_application_form.certification_case_id).certification_id)
      create(:determination, subject: certification, determined_at: submission_date + 2.days, determined_by_id: caseworker.id)
      time_to_close = instance.time_to_close(7.days.ago)
      expect(time_to_close).to eq(1.5.days)
    end

    it "excludes records outside cutoff" do
      submission_date = 6.days.ago
      activity_report_application_form = create(:activity_report_application_form, submitted_at: submission_date)
      create(:determination, subject: activity_report_application_form.certification, determined_at: submission_date + 1.day, determined_by_id: caseworker.id)
      exemption_application_form = create(:exemption_application_form, submitted_at: submission_date)
      certification = Certification.find(CertificationCase.find(exemption_application_form.certification_case_id).certification_id)
      create(:determination, subject: certification, determined_at: submission_date + 2.days, determined_by_id: caseworker.id)
      time_to_close = instance.time_to_close(1.day.ago)
      expect(time_to_close).to be_nil
    end
  end
end
