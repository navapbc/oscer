# frozen_string_literal: true

class TasksController < Strata::TasksController
  before_action :set_certification, only: [ :show ]
  before_action :set_member, only: [ :show ]

  def assign
    set_task
    @task.assign(current_user.id)
    flash["task-message"] = "Task assigned to you."
    redirect_to task_path(@task)
  end

  def request_information
    set_task
    @application_form = @task.class.application_form_class.find_by(certification_case_id: @task.case_id)
    @information_request = @application_form.class.information_request_class.new
    set_create_path

    render "tasks/request_information"
  end

  def create_information_request
    set_task
    result = TaskService.request_more_information(
      @task,
      information_request_params,
    )

    if result[:success]
      redirect_to certification_case_path(@task.case_id), notice: "Request for information sent."
    else
      @information_request = result[:information_request_record]
      set_create_path
      render "tasks/request_information", status: :unprocessable_entity
    end
  end

  protected

  def filter_tasks_by_status(tasks, status)
    status == "completed" \
        ? tasks.without_status(:pending) \
        : tasks.with_status(:pending)
  end

  def set_application_form
    # We do not want to grab the application form class from Certification Case
    # because it can be tied to multiple application form types
    @application_form = @task.class.application_form_class.find_by(certification_case_id: @task.case_id)
  end

  def set_certification
    @certification = Certification.find(@case.certification_id)
  end

  def set_member
    @member = Member.from_certification(@certification)
  end

  def information_request_params
    raise NotImplementedError, "Subclasses must implement information_request_params"
  end
end
