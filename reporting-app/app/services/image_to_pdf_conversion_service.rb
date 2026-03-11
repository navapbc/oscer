# frozen_string_literal: true

class ImageToPdfConversionService
  IMAGE_SIZE_THRESHOLD = 5.megabytes

  CONVERTIBLE_CONTENT_TYPES = %w[
    image/jpeg
    image/png
    image/tiff
  ].freeze

  # Duck-type wrapper for converted files, compatible with DocAiAdapter's
  # expected interface: file.blob.open { |tf| }, file.content_type, file.filename.to_s.
  # Caller is responsible for calling #close! to clean up the tempfile.
  class ConvertedFile
    attr_reader :content_type

    def initialize(tempfile:, original_filename:)
      @tempfile = tempfile
      @original_filename = original_filename
      @content_type = "application/pdf"
    end

    def blob
      self
    end

    def open
      yield @tempfile
    end

    def filename
      @original_filename.sub(/\.\w+\z/, ".pdf")
    end

    def close!
      @tempfile.close!
    end
  end

  # Converts image files >5MB to PDF for DocAI API compatibility.
  # Returns the original file unchanged if: PDF, ≤5MB, unsupported type, or conversion fails.
  # Returns a ConvertedFile wrapper when conversion occurs — caller must call #close! to clean up.
  def convert(file)
    return file if pdf?(file)
    return file unless convertible_image?(file)
    return file unless exceeds_size_threshold?(file)

    convert_to_pdf(file)
  end

  private

  def pdf?(file)
    file.blob.content_type == "application/pdf"
  end

  def convertible_image?(file)
    CONVERTIBLE_CONTENT_TYPES.include?(file.blob.content_type)
  end

  def exceeds_size_threshold?(file)
    file.blob.byte_size > IMAGE_SIZE_THRESHOLD
  end

  # blob.open downloads from S3 to a temp file, yields it, then cleans up the
  # INPUT tempfile on block exit. ImageProcessing#call returns an independent
  # OUTPUT Tempfile that survives beyond the block — vips reads eagerly during
  # .call, so the input is fully consumed before cleanup.
  def convert_to_pdf(file)
    require "image_processing/vips"

    converted_tempfile = file.blob.open do |tempfile|
      ImageProcessing::Vips
        .source(tempfile)
        .convert("pdf")
        .call
    end

    ConvertedFile.new(tempfile: converted_tempfile, original_filename: file.blob.filename.to_s)
  rescue StandardError => e
    Rails.logger.warn(
      "[ImageToPdfConversionService] Conversion failed for blob #{file.blob.id}: " \
      "#{e.class} - #{e.message}. Returning original file."
    )
    file
  end
end
