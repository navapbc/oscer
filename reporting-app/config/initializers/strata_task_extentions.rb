# frozen_string_literal: true

Rails.application.config.to_prepare do
  Strata::Task.class_eval do
    scope :by_region, ->(region) {
      tasks = arel_table
      cases = CertificationCase.arel_table
      certs = Certification.arel_table

      join_conditions = tasks[:case_id].eq(cases[:id])
        .and(tasks[:case_type].eq("CertificationCase"))

      joins(
        tasks.join(cases, Arel::Nodes::InnerJoin).on(join_conditions)
          .join(certs, Arel::Nodes::InnerJoin).on(cases[:certification_id].eq(certs[:id]))
          .join_sources
      ).merge(Certification.by_region(region))
    }
  end
end
