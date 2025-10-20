# frozen_string_literal: true

class ReviewExemptionClaimTasksController < TasksController
  def update
    kase = @task.case

    if approving?
      kase.accept_exemption_request
      notice = t("tasks.details.approved_message")
    elsif denying?
      kase.deny_exemption_request
      notice = t("tasks.details.denied_message")
    elsif requesting_information?
      # Redirect to new information request form. Task will be marked as "on hold" when
      # the information request is created.
      redirect_to(action: :request_information)
      return
    else
      raise "Invalid action"
    end

    @task.completed!

    respond_to do |format|
      format.html { redirect_to task_path(@task), notice: }
      format.json { render :show, status: :ok, location: task_path(@task) }
    end
  end

  private

  def approving?
    exemption_decision == "yes"
  end

  def denying?
    exemption_decision == "no-not-acceptable"
  end

  def requesting_information?
    exemption_decision == "no-additional-info"
  end

  def exemption_decision
    params.dig(:review_exemption_claim_task, :exemption_decision)
  end

  def set_create_path
    @create_path = create_information_request_review_exemption_claim_task_path
  end

  def information_request_params
    params.require(:exemption_information_request).permit(:staff_comment)
  end
end
