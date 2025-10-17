# frozen_string_literal: true

class Demo::CertificationsController < ApplicationController
  layout "demo"

  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def new
    certification_type = params.fetch(:certification_type, nil)
    certification_requirement_params = certification_service.certification_type_requirement_params(certification_type) || {}
    @form = Demo::Certifications::CreateForm.new({ certification_type: certification_type }.merge(certification_requirement_params.as_json))
  end

  def create
    @form = Demo::Certifications::CreateForm.new(form_params)

    if @form.invalid?
      flash.now[:errors] = @form.errors.full_messages
      return render :new, status: :unprocessable_entity
    end

    certification_requirements = certification_service.calculate_certification_requirements(Certifications::RequirementParams.new_filtered(@form.attributes.with_indifferent_access))

    # TODO: Eventually create a Service to handle member data construction

    member_data = {
      "name": Certifications::MemberDataName.from_strata(@form.member_name)
    }

    case @form.ex_parte_scenario
    when "Partially met work hours requirement"
      member_data.merge!(FactoryBot.build(:certification_member_data, :partially_met_work_hours_requirement, cert_date: @form.certification_date).attributes)
    when "Fully met work hours requirement"
      member_data.merge!(FactoryBot.build(:certification_member_data, :fully_met_work_hours_requirement, cert_date: @form.certification_date, num_months: @form.number_of_months_to_certify).attributes)
    else
      # nothing
    end

    @certification = FactoryBot.build(
      :certification,
      :connected_to_email,
      email: @form.member_email,
      case_number: @form.case_number,
      certification_requirements: certification_requirements,
      member_data: Certifications::MemberData.new_filtered(member_data),
    )

    if @certification.save
      redirect_to certification_path(@certification)
    else
      flash.now[:errors] = @certification.errors.full_messages
      render :new, status: :unprocessable_entity
    end
  end

  private
    def certification_service
      CertificationService.new
    end

    def form_params
      params.require(:demo_certifications_create_form)
            .permit(
              :member_email, :case_number, :certification_type, :certification_date, :lookback_period,
              :number_of_months_to_certify, :due_period_days, :ex_parte_scenario,
              :member_name_first, :member_name_middle, :member_name_last, :member_name_suffix
            )
    end
end
