class OscerTask < Strata::Task
  # TODO: Figure out a better way to handle default due dates for tasks
  attribute :due_on, :date, default: -> { 7.days.from_now.to_date }

  # This doesn't currently work because it adds a WHERE for task.type = 'OscerTask', which finds no records
  # scope :for_region, ->(region) { 
  #   joins("INNER JOIN certification_cases ON certification_cases.id = strata_tasks.case_id")
  #   .joins("INNER JOIN certifications ON certifications.id = certification_cases.certification_id")
  #   .where("certifications.certification_requirements->>'region' = ?", region) 
  # }

  def self.policy_class
    TaskPolicy
  end
end