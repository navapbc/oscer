# frozen_string_literal: true

class ReportingService
  def time_to_close(cutoff)
    application_form_delta_generator = time_to_close_sql_generator(ActivityReportApplicationForm.arel_table, cutoff)
    exemption_form_delta_generator = time_to_close_sql_generator(ExemptionApplicationForm.arel_table, cutoff)

    union_delta_generator = application_form_delta_generator.union(exemption_form_delta_generator)

    alias_table = Arel::Nodes::TableAlias.new(union_delta_generator, "tmp")

    final_query = Arel::SelectManager.new(Arel::Table.engine)
                    .from(alias_table)
                    .project("EXTRACT(EPOCH FROM PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delta)) AS result")
    result = ActiveRecord::Base.connection.exec_query(final_query.to_sql)

    result.first["result"]
  end

  private

  def time_to_close_sql_generator(form_table, cutoff)
    det_table = Determination.arel_table
    cc_table = CertificationCase.arel_table
    det_table.join(cc_table).on(det_table[:subject_id].eq(cc_table[:certification_id]))
      .join(form_table).on(cc_table[:id].eq(form_table[:certification_case_id]))
      .where(
        det_table[:subject_type].eq("Certification")
          .and(det_table[:determined_by_id].not_eq(nil))
          .and(det_table[:determined_at].gt(cutoff))
          .and(det_table[:determined_at].gt(form_table[:submitted_at])))
      .project((det_table[:determined_at] - form_table[:submitted_at]).as("delta"))
  end
end
