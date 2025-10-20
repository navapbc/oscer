# frozen_string_literal: true

class ReviewActivityReportTasksController < TasksController
  def update
    kase = @task.case

    if approving?
      kase.accept_activity_report
      notice = t("tasks.details.approved_message")
    elsif denying?
      kase.deny_activity_report
      notice = t("tasks.details.denied_message")
    elsif requesting_information?
      # Redirect to new information request form. Task will be marked as "on hold" when
      # the information request is created.
      redirect_to(action: :request_information)
      return
    else
      notice = t("tasks.details.no_decision_made_message")
    end

    @task.completed!

    respond_to do |format|
      format.html { redirect_to task_path(@task), notice: }
      format.json { render :show, status: :ok, location: task_path(@task) }
    end
  end

  private

  def approving?
    activity_report_decision == "yes"
  end

  def denying?
    activity_report_decision == "no-not-acceptable"
  end

  def requesting_information?
    activity_report_decision == "no-additional-info"
  end

  def activity_report_decision
    params.dig(:review_activity_report_task, :activity_report_decision)
  end

  def set_create_path
    @create_path = create_information_request_review_activity_report_task_path
  end

  def information_request_params
    params.require(:activity_report_information_request).permit(:staff_comment)
  end
end
