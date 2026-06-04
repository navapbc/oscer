# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  include Warden::Test::Helpers

  let(:member_data) { build(:certification_member_data, :with_account_email) }
  let!(:certification) { create(:certification, member_data: member_data) }
  let(:user) { create(:user, email: member_data.account_email) }
  let(:certification_case) { create(:certification_case, certification: certification) }

  before do
    allow(Strata::EventManager).to receive(:publish).and_call_original
    allow(ExemptionDeterminationService).to receive(:determine)
    allow(IncomeComplianceDeterminationService).to receive(:calculate)
    allow(CommunityEngagementCheckService).to receive(:determine) do |kase|
      Strata::EventManager.publish("DeterminedCommunityEngagementActionRequired", {
        case_id: kase.id,
        certification_id: kase.certification_id
      })
    end
    allow(NotificationService).to receive(:send_email_notification)

    login_as user
    certification_case
  end

  after do
    Warden.test_reset!
  end

  describe "GET /dashboard" do
    it "returns success and renders member compliance content" do
      get dashboard_path

      title = I18n.t("dashboard.member_compliance.exemption_alerts.not_started.title")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(ERB::Util.html_escape(title))
      expect(response.body).to include(I18n.t("dashboard.welcome_hero.heading"))
    end

    it "does not fail if no application form" do
      get dashboard_path

      expect(response).to be_ok
    end

    it "sets the activity report application form" do
      form = create(:activity_report_application_form, user_id: user.id, certification_case_id: certification_case.id)
      get dashboard_path

      expect(response.body).to include(activity_report_application_form_path(form))
    end

    it "sets the in-progress activity report application form if more than one form" do
      submitted_form = create(:activity_report_application_form, :with_submitted_status, user_id: user.id,
                              certification_case_id: certification_case.id)
      form = create(:activity_report_application_form, user_id: user.id, certification_case_id: certification_case.id)
      get dashboard_path

      expect(response.body).not_to include(activity_report_application_form_path(submitted_form))
      expect(response.body).to include(activity_report_application_form_path(form))
    end

    it "sets the most recent activity report application form if only submitted exist" do
      older_submitted_form = create(:activity_report_application_form, :with_submitted_status, user_id: user.id,
                                    certification_case_id: certification_case.id, created_at: 1.day.ago)
      younger_submitted_form = create(:activity_report_application_form, :with_submitted_status, user_id: user.id,
                                      certification_case_id: certification_case.id)
      get dashboard_path

      expect(response.body).not_to include(activity_report_application_form_path(older_submitted_form))
      expect(response.body).to include(activity_report_application_form_path(younger_submitted_form))
    end

    it "sets the exemption application form" do
      form = create(:exemption_application_form, user_id: user.id, certification_case_id: certification_case.id)
      get dashboard_path

      expect(response.body).to include(exemption_application_form_path(form))
    end

    it "sets the in-progress exemption application form if more than one form" do
      submitted_form = create(:exemption_application_form, :with_submitted_status, user_id: user.id,
                              certification_case_id: certification_case.id)
      form = create(:exemption_application_form, user_id: user.id, certification_case_id: certification_case.id)
      get dashboard_path

      expect(response.body).not_to include(exemption_application_form_path(submitted_form))
      expect(response.body).to include(exemption_application_form_path(form))
    end

    it "sets the most recent exemption application form if only submitted exist" do
      older_submitted_form = create(:exemption_application_form, :with_submitted_status, user_id: user.id,
                                    certification_case_id: certification_case.id, created_at: 1.day.ago)
      younger_submitted_form = create(:exemption_application_form, :with_submitted_status, user_id: user.id,
                                      certification_case_id: certification_case.id)
      get dashboard_path

      expect(response.body).not_to include(exemption_application_form_path(older_submitted_form))
      expect(response.body).to include(exemption_application_form_path(younger_submitted_form))
    end

    context "when awaiting report without income UI" do
      it "does not query external income before income fields are read" do
        allow(ExternalIncomeActivity).to receive(:for_member).and_call_original

        get dashboard_path

        expect(response).to have_http_status(:ok)
        expect(ExternalIncomeActivity).not_to have_received(:for_member)
      end
    end

    context "with an in-progress activity report" do
      it "renders continue reporting actions" do
        create(:activity_report_application_form, user_id: user.id, certification_case_id: certification_case.id)
        get dashboard_path

        expect(response.body).to include(I18n.t("dashboard.member_compliance.reporting.continue_button"))
      end

      context "when doc_ai is enabled and skip is not set" do
        let!(:activity_report_application_form) do
          create(:activity_report_application_form, user_id: user.id, certification_case_id: certification_case.id)
        end

        it "links continue to the doc ai upload path" do
          with_doc_ai_enabled do
            get dashboard_path

            expect(response.body).to include(
              doc_ai_upload_activity_report_application_form_path(activity_report_application_form)
            )
          end
        end
      end

      context "when doc_ai is enabled and skip is set" do
        it "links continue to the activity report form path" do
          with_doc_ai_enabled do
            post activity_report_application_forms_url,
                 params: {
                   activity_report_application_form: {
                     certification_case_id: certification_case.id,
                     skip_ai: "1"
                   }
                 }
            form = ActivityReportApplicationForm.find_by!(certification_case_id: certification_case.id)
            get dashboard_path

            expect(response.body).to include(activity_report_application_form_path(form))
            expect(response.body).not_to include(
              doc_ai_upload_activity_report_application_form_path(form)
            )
          end
        end
      end

      context "when doc_ai is disabled" do
        let!(:activity_report_application_form) do
          create(:activity_report_application_form, user_id: user.id, certification_case_id: certification_case.id)
        end

        it "links continue to the activity report form path" do
          with_doc_ai_disabled do
            get dashboard_path

            expect(response.body).to include(
              activity_report_application_form_path(activity_report_application_form)
            )
            expect(response.body).not_to include(
              doc_ai_upload_activity_report_application_form_path(activity_report_application_form)
            )
          end
        end
      end
    end

    context "with a submitted activity report" do
      before do
        create(:activity_report_application_form, :with_submitted_status, user_id: user.id,
               certification_case_id: certification_case.id)
        certification_case.reload
      end

      it "renders the submitted activity report view action" do
        get dashboard_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(
          I18n.t("dashboard.activity_report_submitted.view_activity_report_button")
        )
        expect(response.body).not_to include(I18n.t("dashboard.member_compliance.reporting.continue_button"))
      end
    end

    context "with a completed prior certification" do
      let!(:older_certification) { create(:certification, member_data: member_data) }

      before do
        create(:certification_case, certification: older_certification)
        create(:determination,
               subject: older_certification,
               outcome: "compliant",
               decision_method: "manual",
               reasons: [ "hours_reported_compliant" ])
        older_certification.update!(created_at: 2.months.ago)
        certification.update!(created_at: 1.day.ago)
      end

      it "renders the previous completed requirements section" do
        get dashboard_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("dashboard.index.previous_certifications.title"))
      end
    end

    context "with a prior certification still in progress" do
      let!(:older_certification) { create(:certification, member_data: member_data) }

      before do
        create(:certification_case, certification: older_certification)
        older_certification.update!(created_at: 2.months.ago)
        certification.update!(created_at: 1.day.ago)
      end

      it "does not render the previous completed requirements section" do
        get dashboard_path

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include(I18n.t("dashboard.index.previous_certifications.title"))
      end
    end
  end
end
