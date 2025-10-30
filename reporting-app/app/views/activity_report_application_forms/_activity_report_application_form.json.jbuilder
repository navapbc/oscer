# frozen_string_literal: true

json.extract! activity_report_application_form, :id, :created_at, :updated_at
json.url activity_report_application_form_url(activity_report_application_form, format: :json)
