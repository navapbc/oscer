# frozen_string_literal: true

json.extract! exemption_application_form, :id, :created_at, :updated_at
json.url exemption_application_form_url(exemption_application_form, format: :json)
