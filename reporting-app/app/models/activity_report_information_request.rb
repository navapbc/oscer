# frozen_string_literal: true

class ActivityReportInformationRequest < InformationRequest
  def self.task_class
    ReviewActivityReportTask
  end
end
