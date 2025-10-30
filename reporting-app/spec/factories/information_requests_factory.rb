# frozen_string_literal: true

FactoryBot.define do
  factory :information_request do
    staff_comment { "Please provide more information." }
    due_date { 1.week.from_now }
  end

  factory :exemption_information_request, parent: :information_request, class: "ExemptionInformationRequest" do
    application_form_id { create(:exemption_application_form).id }
    application_form_type { "ExemptionApplicationForm" }
  end

  factory :activity_report_information_request, parent: :information_request, class: "ActivityReportInformationRequest" do
    application_form_id { create(:activity_report_application_form).id }
    application_form_type { "ActivityReportApplicationForm" }
  end
end
