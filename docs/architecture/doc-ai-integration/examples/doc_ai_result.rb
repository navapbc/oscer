# app/models/doc_ai_result.rb
class DocAiResult < Strata::ValueObject
  include Strata::Attributes

  # Wraps a single extracted field's value and confidence score.
  FieldValue = Data.define(:value, :confidence) do
    def low_confidence?
      confidence.nil? || confidence < Rails.application.config.doc_ai[:low_confidence_threshold]
    end
    def to_s = value.to_s
  end

  # Subclass registry — populated at load time by each subclass calling .register.
  # Subclass files must be required below the class definition so they register before
  # from_response is called (Rails eager loading handles this in production automatically).
  REGISTRY = {}

  # Called by each subclass to associate its DocAI document class name with the Ruby class.
  def self.register(document_class)
    REGISTRY[document_class] = self
  end

  # Response envelope
  strata_attribute :job_id, :string
  strata_attribute :status, :string
  strata_attribute :matched_document_class, :string
  strata_attribute :message, :string
  strata_attribute :created_at, :datetime
  strata_attribute :completed_at, :datetime
  strata_attribute :total_processing_time_seconds, :float
  strata_attribute :error, :string           # present when status == "failed"
  strata_attribute :additional_info, :string # present when status == "failed"

  # Raw fields hash — preserves all confidence + value pairs from the API.
  # Stored as a plain Hash; frozen in build to prevent mutation.
  attr_reader :fields

  # Factory: dispatches to the registered subclass for the given matchedDocumentClass.
  # Falls back to base DocAiResult for unregistered document types.
  def self.from_response(response)
    klass = REGISTRY.fetch(response["matchedDocumentClass"], DocAiResult)
    klass.build(response)
  end

  def self.build(response)
    instance = new(
      job_id:                        response["job_id"],
      status:                        response["status"],
      matched_document_class:        response["matchedDocumentClass"],
      message:                       response["message"],
      created_at:                    response["createdAt"],
      completed_at:                  response["completedAt"],
      total_processing_time_seconds: response["totalProcessingTimeSeconds"],
      error:                         response["error"],
      additional_info:               response["additionalInfo"]
    )
    instance.instance_variable_set(:@fields, (response["fields"] || {}).freeze)
    instance
  end

  def completed? = status == "completed"
  def failed?    = status == "failed"

  # Returns a FieldValue containing both the extracted value and its confidence score.
  # Returns nil if the field was not present in the API response.
  def field_for(api_key)
    raw = fields.dig(api_key.to_s)
    return nil unless raw
    FieldValue.new(value: raw["value"], confidence: raw["confidence"])
  end

  # Subclasses override to return a hash of { field_name: value } for form prefill.
  # Base implementation returns an empty hash.
  def to_prefill_fields = {}

  # Subclass files are required explicitly so their .register calls populate REGISTRY
  # before any call to DocAiResult.from_response.
  require_relative "doc_ai_result/payslip"
  require_relative "doc_ai_result/w2"

  # Freeze the registry after all subclasses have loaded to prevent accidental
  # post-load mutation. Any require_relative for new document types must appear above.
  REGISTRY.freeze
end
