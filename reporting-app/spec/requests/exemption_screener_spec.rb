# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "ExemptionScreeners", type: :request do
  include Warden::Test::Helpers

  let(:user) { create(:user) }
  let(:certification) { create(:certification, :connected_to_email, email: user.email) }
  let(:certification_case) { create(:certification_case, certification: certification) }
  let(:enabled_types) { Exemption.enabled.map { |t| t[:id] } }
  let(:first_exemption_type) { enabled_types.first }
  let(:second_exemption_type) { enabled_types.second }
  let(:last_exemption_type) { enabled_types.last }

  before do
    login_as user
  end

  describe "GET /exemption-screener" do
    context "with valid certification case" do
      it "renders the intro page" do
        get exemption_screener_path(certification_case_id: certification_case.id)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Tell us about your situation")
        expect(response.body).to include("Start")
      end

      it "displays step indicator with Start as current step" do
        get exemption_screener_path(certification_case_id: certification_case.id)

        expect(response.body).to include("usa-step-indicator")
        expect(response.body).to include("usa-step-indicator__segment--current")
      end
    end

    context "without certification_case_id" do
      it "redirects to dashboard" do
        get exemption_screener_path

        expect(response).to redirect_to(dashboard_path)
      end
    end

    context "when exemption application already exists" do
      before do
        create(:exemption_application_form,
          certification_case_id: certification_case.id,
          user_id: user.id
        )
      end

      it "redirects to dashboard with notice" do
        get exemption_screener_path(certification_case_id: certification_case.id)

        expect(response).to redirect_to(dashboard_path)
        follow_redirect!
        expect(response.body).to include("already have an exemption application")
      end
    end
  end

  describe "GET /exemption-screener/question/:exemption_type" do
    it "renders the question page" do
      get exemption_screener_question_path(
        exemption_type: first_exemption_type,
        certification_case_id: certification_case.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include(Exemption.question_for(first_exemption_type))
    end

    it "displays step indicator with current exemption type highlighted" do
      get exemption_screener_question_path(
        exemption_type: first_exemption_type,
        certification_case_id: certification_case.id
      )

      expect(response.body).to include("usa-step-indicator")
      expect(response.body).to include("usa-step-indicator__segment--current")
      expect(response.body).to include("Exemption Questions")
    end

    context "with invalid exemption_type" do
      it "redirects to screener index" do
        get exemption_screener_question_path(
          exemption_type: "invalid_type",
          certification_case_id: certification_case.id
        )

        expect(response).to redirect_to(
          exemption_screener_path(certification_case_id: certification_case.id)
        )
      end
    end

    context "when not first exemption type" do
      it "includes back link to previous exemption type" do
        get exemption_screener_question_path(
          exemption_type: second_exemption_type,
          certification_case_id: certification_case.id
        )

        expect(response.body).to include("Previous Question")
      end
    end
  end

  describe "POST /exemption-screener/question/:exemption_type" do
    context "when answer is yes" do
      it "redirects to may_qualify page" do
        post exemption_screener_answer_question_path(
          exemption_type: first_exemption_type,
          certification_case_id: certification_case.id
        ), params: { answer: "yes" }

        expect(response).to redirect_to(
          exemption_screener_may_qualify_path(
            exemption_type: first_exemption_type,
            certification_case_id: certification_case.id
          )
        )
      end
    end

    context "when answer is no" do
      it "redirects to next exemption type" do
        post exemption_screener_answer_question_path(
          exemption_type: first_exemption_type,
          certification_case_id: certification_case.id
        ), params: { answer: "no" }

        expect(response).to redirect_to(
          exemption_screener_question_path(
            exemption_type: second_exemption_type,
            certification_case_id: certification_case.id
          )
        )
      end
    end

    context "when answer is blank (defaults to no)" do
      it "redirects to next exemption type" do
        post exemption_screener_answer_question_path(
          exemption_type: first_exemption_type,
          certification_case_id: certification_case.id
        )

        # Should behave like "no" answer
        expect(response).to redirect_to(
          exemption_screener_question_path(
            exemption_type: second_exemption_type,
            certification_case_id: certification_case.id
          )
        )
      end
    end

    context "when on last exemption type" do
      it "redirects to complete page when answer is no" do
        post exemption_screener_answer_question_path(
          exemption_type: last_exemption_type,
          certification_case_id: certification_case.id
        ), params: { answer: "no" }

        expect(response).to redirect_to(
          exemption_screener_complete_path(certification_case_id: certification_case.id)
        )
      end
    end
  end

  describe "GET /exemption-screener/may-qualify/:exemption_type" do
    it "renders the may qualify page" do
      get exemption_screener_may_qualify_path(
        exemption_type: first_exemption_type,
        certification_case_id: certification_case.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include("You may not need to report your work hours")
      expect(response.body).to include("Supporting documents")
      expect(response.body).to include("Request an exemption")
    end

    it "displays exemption-specific information from config" do
      get exemption_screener_may_qualify_path(
        exemption_type: first_exemption_type,
        certification_case_id: certification_case.id
      )

      expect(response.body).to include(Exemption.title_for(first_exemption_type))
    end

    it "displays step indicator with Result as current step" do
      get exemption_screener_may_qualify_path(
        exemption_type: first_exemption_type,
        certification_case_id: certification_case.id
      )

      expect(response.body).to include("usa-step-indicator")
      expect(response.body).to include("usa-step-indicator__segment--current")
    end
  end

  describe "POST /exemption-screener/may-qualify/:exemption_type" do
    it "creates an ExemptionApplicationForm with correct type" do
      expect {
        post exemption_screener_create_application_path(
          exemption_type: first_exemption_type,
          certification_case_id: certification_case.id
        )
      }.to change(ExemptionApplicationForm, :count).by(1)

      form = ExemptionApplicationForm.last
      expect(form.exemption_type).to eq(first_exemption_type.to_s)
      expect(form.certification_case_id).to eq(certification_case.id)
      expect(form.user_id).to eq(user.id)
    end

    it "redirects to documents upload page" do
      post exemption_screener_create_application_path(
        exemption_type: first_exemption_type,
        certification_case_id: certification_case.id
      )

      form = ExemptionApplicationForm.last
      expect(response).to redirect_to(documents_exemption_application_form_path(form))
    end

    context "when application already exists (race condition)" do
      before do
        create(:exemption_application_form,
          certification_case_id: certification_case.id,
          user_id: user.id
        )
      end

      it "redirects to dashboard with notice" do
        post exemption_screener_create_application_path(
          exemption_type: first_exemption_type,
          certification_case_id: certification_case.id
        )

        expect(response).to redirect_to(dashboard_path)
      end
    end
  end

  describe "GET /exemption-screener/complete" do
    it "renders the complete page" do
      get exemption_screener_complete_path(certification_case_id: certification_case.id)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("No exemptions apply to your situation")
      expect(response.body).to include("Report activities")
    end

    it "includes link to activity report" do
      get exemption_screener_complete_path(certification_case_id: certification_case.id)

      expect(response.body).to include(
        new_activity_report_application_form_path(certification_case_id: certification_case.id)
      )
    end

    it "displays step indicator with Result as current step" do
      get exemption_screener_complete_path(certification_case_id: certification_case.id)

      expect(response.body).to include("usa-step-indicator")
      expect(response.body).to include("usa-step-indicator__segment--current")
    end
  end
end
