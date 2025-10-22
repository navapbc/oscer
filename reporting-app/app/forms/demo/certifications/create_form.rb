# frozen_string_literal: true

module Demo
  module Certifications
    class CreateForm < BaseCreateForm
      EX_PARTE_SCENARIO_OPTIONS = [ "No data", "Partially met work hours requirement", "Fully met work hours requirement", "Meets age-based exemption requirement" ]

      attribute :ex_parte_scenario, :enum, options: EX_PARTE_SCENARIO_OPTIONS
    end
  end
end
