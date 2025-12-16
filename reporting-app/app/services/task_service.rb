# frozen_string_literal: true

module TaskService
  def self.request_more_information(task, params)
    ActiveRecord::Base.transaction do
      application_form = task.class.application_form_class.find_by(certification_case_id: task.case_id)
      information_request = application_form.class.information_request_class.new(params)
      information_request.application_form_id = application_form.id
      information_request.application_form_type = application_form.class.name
      information_request.save!
      task.on_hold!
    end

    { success: true }
  rescue ActiveRecord::RecordInvalid => e
    { success: false, information_request_record: e.record }
  end

  def self.fulfill_information_request(information_request, params)
    ActiveRecord::Base.transaction do
      information_request.update!(params)
      application_form = information_request.application_form_type.constantize.find(information_request.application_form_id)
      task = information_request.class.task_class.find_by!(
        case_id: application_form.certification_case_id,
        status: :on_hold
      )
      task.pending!
    end

    { success: true }
  rescue ActiveRecord::RecordInvalid
    { success: false, information_request: information_request }
  rescue ActiveRecord::RecordNotFound
    { success: false, information_request: information_request }
  end

  def self.get_region_for_task(task)
    certification = Certification.find_by(id: task.case.certification_id)
    certification&.region
  end
end
