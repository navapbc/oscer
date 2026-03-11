# frozen_string_literal: true

require "rails_helper"
require "image_processing/vips"

# Plain Ruby objects satisfying the ActiveStorage attachment interface.
# ActiveStorage::Attached::One delegates #blob via ActiveRecord's attachment
# machinery (not a regular instance method), so instance_double can't verify it.
module ImageToPdfConversionServiceSpecHelpers
  class FakeBlob
    attr_reader :id, :content_type, :byte_size, :filename

    def initialize(id:, content_type:, byte_size:, filename:, input_tempfile:)
      @id = id
      @content_type = content_type
      @byte_size = byte_size
      @filename = filename
      @input_tempfile = input_tempfile
    end

    def open
      yield @input_tempfile
    end
  end

  class FakeAttachment
    attr_reader :blob

    delegate :content_type, :filename, to: :blob

    def initialize(blob:)
      @blob = blob
    end
  end
end

RSpec.describe ImageToPdfConversionService do
  subject(:service) { described_class.new }

  let(:converted_tempfile) { Tempfile.new([ "converted", ".pdf" ]) }
  let(:input_tempfile) { Tempfile.new("test") }
  # object_double verifies against a real Builder instance, which correctly
  # responds to method_missing-based methods like .convert and .call.
  let(:pipeline) { object_double(ImageProcessing::Vips.source(input_tempfile)) }

  before do
    allow(ImageProcessing::Vips).to receive(:source).and_return(pipeline)
    allow(pipeline).to receive(:convert).with("pdf").and_return(pipeline)
    allow(pipeline).to receive(:call).and_return(converted_tempfile)
  end

  after do
    converted_tempfile.close!
    input_tempfile.close! unless input_tempfile.closed?
  end

  def build_attachment(content_type:, byte_size:, filename: "test.jpg")
    blob = ImageToPdfConversionServiceSpecHelpers::FakeBlob.new(
      id: 1,
      content_type:,
      byte_size:,
      filename: ActiveStorage::Filename.new(filename),
      input_tempfile: input_tempfile
    )
    ImageToPdfConversionServiceSpecHelpers::FakeAttachment.new(blob:)
  end

  describe "#convert" do
    context "when file is a PDF" do
      let(:file) { build_attachment(content_type: "application/pdf", byte_size: 10.megabytes) }

      it "returns the original file unchanged" do
        expect(service.convert(file)).to eq(file)
        expect(ImageProcessing::Vips).not_to have_received(:source)
      end
    end

    context "when file is a JPEG ≤ 5MB" do
      let(:file) { build_attachment(content_type: "image/jpeg", byte_size: 4.megabytes) }

      it "returns the original file unchanged" do
        expect(service.convert(file)).to eq(file)
        expect(ImageProcessing::Vips).not_to have_received(:source)
      end
    end

    context "when file is a JPEG > 5MB" do
      let(:file) { build_attachment(content_type: "image/jpeg", byte_size: 6.megabytes, filename: "photo.jpg") }

      it "returns a ConvertedFile wrapping the converted PDF" do
        result = service.convert(file)

        expect(result).to be_a(described_class::ConvertedFile)
        expect(result.content_type).to eq("application/pdf")
        expect(result.filename).to eq("photo.pdf")
        expect(ImageProcessing::Vips).to have_received(:source)
        expect(pipeline).to have_received(:convert).with("pdf")
        expect(pipeline).to have_received(:call)
      end

      it "yields the converted tempfile via blob.open" do
        result = service.convert(file)

        result.blob.open do |tempfile|
          expect(tempfile).to eq(converted_tempfile)
        end
      end
    end

    context "when file is a PNG > 5MB" do
      let(:file) { build_attachment(content_type: "image/png", byte_size: 6.megabytes, filename: "scan.png") }

      it "returns a ConvertedFile with PDF content type and filename" do
        result = service.convert(file)

        expect(result).to be_a(described_class::ConvertedFile)
        expect(result.content_type).to eq("application/pdf")
        expect(result.filename).to eq("scan.pdf")
      end
    end

    context "when file is a TIFF > 5MB" do
      let(:file) { build_attachment(content_type: "image/tiff", byte_size: 6.megabytes, filename: "doc.tiff") }

      it "returns a ConvertedFile with PDF content type and filename" do
        result = service.convert(file)

        expect(result).to be_a(described_class::ConvertedFile)
        expect(result.content_type).to eq("application/pdf")
        expect(result.filename).to eq("doc.pdf")
      end
    end

    context "when original filename has multiple dots" do
      let(:file) { build_attachment(content_type: "image/tiff", byte_size: 6.megabytes, filename: "my.document.scan.tiff") }

      it "only replaces the final extension with .pdf" do
        result = service.convert(file)

        expect(result.filename).to eq("my.document.scan.pdf")
      end
    end

    context "when file is exactly 5MB (boundary)" do
      let(:file) { build_attachment(content_type: "image/jpeg", byte_size: 5.megabytes) }

      it "returns the original file unchanged (threshold is strictly greater than)" do
        expect(service.convert(file)).to eq(file)
        expect(ImageProcessing::Vips).not_to have_received(:source)
      end
    end

    context "when file has an unsupported content type" do
      let(:file) { build_attachment(content_type: "image/bmp", byte_size: 6.megabytes) }

      it "returns the original file unchanged" do
        expect(service.convert(file)).to eq(file)
        expect(ImageProcessing::Vips).not_to have_received(:source)
      end
    end

    context "when vips conversion fails" do
      let(:file) { build_attachment(content_type: "image/jpeg", byte_size: 6.megabytes) }

      before do
        allow(pipeline).to receive(:call).and_raise(Vips::Error, "conversion failed")
      end

      it "logs a warning and returns the original file" do
        allow(Rails.logger).to receive(:warn)

        expect(service.convert(file)).to eq(file)
        expect(Rails.logger).to have_received(:warn).with(
          /\[ImageToPdfConversionService\] Conversion failed for blob 1.*Vips::Error.*conversion failed/
        )
      end
    end

    context "when blob.open fails (S3 error)" do
      let(:file) { build_attachment(content_type: "image/jpeg", byte_size: 6.megabytes) }

      before do
        allow(file.blob).to receive(:open).and_raise(
          ActiveStorage::FileNotFoundError, "file not found in storage"
        )
      end

      it "logs a warning and returns the original file" do
        allow(Rails.logger).to receive(:warn)

        expect(service.convert(file)).to eq(file)
        expect(Rails.logger).to have_received(:warn).with(
          /\[ImageToPdfConversionService\] Conversion failed for blob 1.*FileNotFoundError/
        )
      end
    end
  end
end
