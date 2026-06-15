# frozen_string_literal: true

class AddApprovalStatusToStrataTasks < ActiveRecord::Migration[8.0]
  def up
    add_column :strata_tasks, :approval_status, :string
    # application_form_id was added (OSCER-585) without an index; the per-form outcome
    # delegation now looks tasks up by it, so index it here.
    add_index :strata_tasks, :application_form_id unless index_exists?(:strata_tasks, :application_form_id)

    backfill_approval_status(ReviewActivityReportTask, :activity_report_approval_status)
    backfill_approval_status(ReviewExemptionClaimTask, :exemption_request_approval_status)
  end

  def down
    remove_index :strata_tasks, :application_form_id, if_exists: true
    remove_column :strata_tasks, :approval_status
  end

  private

  # A case can hold multiple forms (and review tasks) after a denial + re-submission.
  # The case fact retains only the most recent decision, so attribute it to the most
  # recent task and treat every superseded task as denied (a later form only exists
  # because the earlier one was denied). Idempotent on re-run.
  def backfill_approval_status(task_class, form_class_approval_status)
    task_class.where.not(case_id: nil).group_by(&:case_id).each do |case_id, tasks|
      kase = CertificationCase.find_by(id: case_id)
      next if kase.nil?

      ordered = tasks.sort_by(&:created_at).reverse
      say "Backfilling #{tasks.size} #{task_class.name}(s) on case #{case_id}" if tasks.size > 1

      ordered.each_with_index do |task, index|
        status = index.zero? ? kase.public_send(form_class_approval_status) : "denied"
        task.update_column(:approval_status, status) # rubocop:disable Rails/SkipsModelValidations
      end
    end
  end
end
