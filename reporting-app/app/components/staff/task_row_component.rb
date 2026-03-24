# frozen_string_literal: true

class Staff::TaskRowComponent < Strata::Tasks::TaskRowComponent
  def initialize(task:, confidence_by_case: nil, **kwargs)
    @confidence_by_case = confidence_by_case
    super(task: task, **kwargs)
  end

  def self.columns
    cols = Strata::Tasks::TaskRowComponent.columns
    return cols unless Features.doc_ai_enabled?
    cols + [ :confidence ]
  end

  def self.header_translation_for(column)
    return I18n.t("staff.tasks.index.confidence") if column == :confidence
    super
  end

  def row_classes
    return nil unless Features.doc_ai_enabled?
    tc = helpers.task_confidence(@task.case_id, @confidence_by_case)
    "bg-error-lighter" if tc[:low]
  end

  protected

  def confidence
    tc = helpers.task_confidence(@task.case_id, @confidence_by_case)
    helpers.confidence_value_content(tc[:conf])
  end

  def cell_classes(column)
    return "text-right text-no-wrap" if column == :confidence
    super
  end
end
