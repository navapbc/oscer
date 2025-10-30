# frozen_string_literal: true

class BusinessProcessesPreview < Lookbook::Preview
  layout "strata/component_preview"

  def certification_business_process
    render template: "strata/previews/_business_process", locals: { business_process: CertificationBusinessProcess }
  end
end
