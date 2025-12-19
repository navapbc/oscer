# frozen_string_literal: true

class TasksController < Strata::TasksController
  before_action :authenticate_user!
  after_action :verify_authorized

  before_action :set_certification, only: [ :show ]
  before_action :set_member, only: [ :show ]
  before_action :set_information_requests, only: [ :show ]

  # Override parent index to use policy_scope for authorization.
  # The parent Strata::TasksController uses Strata::Task.all internally,
  # so we override to inject policy_scope into task queries.
  def index
    @task_types = policy_scope(Strata::Task).unscope(:order).distinct.pluck(:type)
    @tasks = filter_tasks
    @unassigned_tasks = policy_scope(Strata::Task).incomplete.unassigned
  end

  def assign
    set_task
    @task.assign(current_user.id)
    flash["task-message"] = "Task assigned to you."
    redirect_to task_path(@task)
  end

  # Override parent pick_up_next_task to scope tasks by region.
  # The parent Strata::TasksController.pick_up_next_task uses Strata::Task.assign_next_task_to,
  # which doesn't filter by region, so we override to inject policy_scope.
  def pick_up_next_task
    # Scope tasks to user's region before finding next unassigned task
    task = policy_scope(Strata::Task).incomplete.unassigned.first

    if task && task.assign(current_user.id)
      flash["task-message"] = I18n.t("strata.tasks.messages.task_picked_up")
      redirect_to task_path(task)
    else
      flash["task-message"] = I18n.t("strata.tasks.messages.no_tasks_available")
      redirect_to tasks_path
    end
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
      render "tasks/request_information", status: :unprocessable_content
    end
  end

  protected

  def filter_tasks
    policy_scope super, policy_scope_class: Strata::TaskPolicy::Scope
  end

  def filter_tasks_by_status(tasks, status)
    case status
    when "completed"
      tasks.with_status(:completed)
    when "on_hold"
      tasks.with_status(:on_hold)
    else
      tasks.with_status(:pending)
    end
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

  def set_task
    super
    authorize @task
  end

  def set_information_requests
    @information_requests = InformationRequest
      .for_application_forms([ @application_form.id ])
      .order(created_at: :desc)
  end

  def information_request_params
    raise NotImplementedError, "Subclasses must implement information_request_params"
  end

  private

  def authorize_staff_access
    # Authorize only for actions that do not have a specific task instance.
    # All other actions authorize @task in set_task.
    return unless action_name.in?(%w[index pick_up_next_task])

    authorize Strata::Task
  end
end
