# frozen_string_literal: true

class Demo::CertificationsController < ApplicationController
  layout "demo"

  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def new
    @form = Demo::Certifications::CreateForm.new_for_certification_type(
      params.fetch(:certification_type, nil)
    )
  end

  def create
    @form = Demo::Certifications::CreateForm.new(form_params)

    if @form.invalid?
      flash.now[:errors] = @form.errors.full_messages
      return render :new, status: :unprocessable_content
    end

    @certification = @form.to_certification

    if !@certification
      flash.now[:errors] = @form.errors.full_messages
      render :new, status: :unprocessable_content
    end

    if @certification.save
      redirect_to certification_path(@certification)
    else
      flash.now[:errors] = @certification.errors.full_messages
      render :new, status: :unprocessable_content
    end
  end

  private
    def form_params
      params.require(:demo_certifications_create_form)
            .permit(Demo::Certifications::CreateForm.attribute_names.map(&:to_sym))
    end
end
