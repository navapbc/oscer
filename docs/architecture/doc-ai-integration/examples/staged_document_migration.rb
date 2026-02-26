# db/migrate/<timestamp>_create_staged_documents.rb
create_table :staged_documents, id: :uuid do |t|
  t.references :user,              type: :uuid, null: false, foreign_key: true
  t.references :stageable,         polymorphic: true, type: :uuid  # set when consumed by a parent model
  t.string     :status,            null: false, default: "pending"
  t.string     :doc_ai_job_id
  t.string     :doc_ai_matched_class
  t.jsonb      :extracted_fields,  null: false, default: {}
  t.datetime   :validated_at
  t.timestamps
end

add_index :staged_documents, :status
add_index :staged_documents, :doc_ai_job_id
