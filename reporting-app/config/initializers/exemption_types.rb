# frozen_string_literal: true

Rails.application.config.exemption_types = [
  {
    id: :caregiver_disability,
    enabled: true
  },
  {
    id: :caregiver_child,
    enabled: true
  },
  {
    id: :medical_condition,
    enabled: true
  },
  {
    id: :substance_treatment,
    enabled: true
  },
  {
    id: :incarceration,
    enabled: true
  },
  {
    id: :education_and_training,
    enabled: true
  },
  {
    id: :received_medical_care,
    enabled: true
  }
  # TODO: Add federal disaster declaration and medical care travel
]
