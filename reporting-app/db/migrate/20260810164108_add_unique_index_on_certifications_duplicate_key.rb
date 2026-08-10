# frozen_string_literal: true

class AddUniqueIndexOnCertificationsDuplicateKey < ActiveRecord::Migration[8.0]
  def change
    # Enforces API idempotency key used by Certification.find_duplicate /
    # POST /api/certifications. Partial index so rows missing any key
    # component (NULL) are not treated as duplicates — matching app-level
    # blank? guards. Postgres UNIQUE already allows multiple NULLs; the
    # WHERE clause makes that intent explicit.
    add_index :certifications,
      [ :member_id, :case_number, :application_date ],
      unique: true,
      where: "member_id IS NOT NULL AND case_number IS NOT NULL AND application_date IS NOT NULL",
      name: "index_certifications_on_member_case_application_date"
  end
end
