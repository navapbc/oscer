# frozen_string_literal: true

class ExemptionScreenerController < ApplicationController
  before_action :set_certification_case
  before_action :set_certification, if: -> { @certification_case.present? }
  before_action :ensure_certification_case
  before_action :authorize_access
  before_action :check_existing_application
  before_action :set_current_exemption_type, only: %i[show answer may_qualify create_application]
  before_action :setup_navigator, only: %i[show answer]
  before_action :validate_exemption_type, only: %i[show answer]

  skip_after_action :verify_policy_scoped

  # GET /exemption-screener
  # Entry point - displays introductory landing page
  def index
    @first_exemption_type = Exemption.first_type
    @current_step = :start
  end

  # GET /exemption-screener/question/:exemption_type
  # Displays a single yes/no question for the given exemption type
  def show
    @current_question = @navigator.current_question
    @previous_exemption_type = @navigator.previous_location
    @current_step = @current_exemption_type.to_sym
  end

  # POST /exemption-screener/question/:exemption_type
  # Handles yes/no answer submission
  def answer
    action, *location_params = @navigator.next_location(answer: params[:answer])

    case action
    when :may_qualify
      redirect_to exemption_screener_may_qualify_path(
        exemption_type: location_params[0],
        certification_case_id: @certification_case.id
      )
    when :question
      redirect_to exemption_screener_question_path(
        exemption_type: location_params[0],
        certification_case_id: @certification_case.id
      )
    when :complete
      redirect_to exemption_screener_complete_path(
        certification_case_id: @certification_case.id
      )
    end
  end

  # GET /exemption-screener/may-qualify/:exemption_type
  # Shows user they may qualify with exemption details and documentation requirements
  def may_qualify
    @exemption_name = Exemption.title_for(@current_exemption_type)
    @exemption_description = Exemption.description_for(@current_exemption_type)
    @required_documents = Exemption.supporting_documents_for(@current_exemption_type)
    @current_step = :result
  end

  # POST /exemption-screener/may-qualify/:exemption_type
  # Creates the exemption application form when user confirms from may_qualify page
  def create_application
    create_exemption_application
  end

  # GET /exemption-screener/complete
  # Shown when user answers "No" to all questions
  def complete
    # Renders the "you likely need to report activities" page
    @current_step = :result
  end

  private

  def set_certification_case
    @certification_case = CertificationCase.find_by(id: params[:certification_case_id])
  end

  def set_certification
    @certification = Certification.find_by(id: @certification_case.certification_id)
  end

  def ensure_certification_case
    return if @certification_case.present?

    redirect_to dashboard_path, alert: t("exemption_screener.errors.no_certification_case")
  end

  def authorize_access
    # Authorize access to the certification case by checking if user can create an exemption form
    # This uses the ExemptionApplicationFormPolicy which checks user ownership
    authorize ExemptionApplicationForm.new(certification_case_id: @certification_case&.id), :new?
  end

  def check_existing_application
    existing_application = ExemptionApplicationForm.find_by(certification_case_id: @certification_case&.id)

    return unless existing_application.present?

    redirect_to dashboard_path,
      notice: t("exemption_screener.errors.application_exists")
  end

  def set_current_exemption_type
    @current_exemption_type = params[:exemption_type]
  end

  def setup_navigator
    @navigator = ExemptionScreenerNavigator.new(@current_exemption_type)
  end

  def validate_exemption_type
    unless @navigator.valid?
      redirect_to exemption_screener_path(certification_case_id: @certification_case.id),
        alert: t("exemption_screener.errors.invalid_question")
    end
  end

  def create_exemption_application
    form = ExemptionApplicationForm.new(
      certification_case_id: @certification_case.id,
      user_id: current_user.id,
      exemption_type: @current_exemption_type
    )

    if form.save
      redirect_to documents_exemption_application_form_path(form),
        notice: t("exemption_screener.success.application_created")
    else
      handle_creation_error(form)
    end
  end

  def handle_creation_error(form)
    if form.errors[:certification_case_id].include?("has already been taken")
      redirect_to dashboard_path,
        notice: t("exemption_screener.errors.application_exists")
    else
      redirect_to exemption_screener_may_qualify_path(
        exemption_type: @current_exemption_type,
        certification_case_id: @certification_case.id
      ), alert: t("exemption_screener.errors.creation_failed")
    end
  end
end
