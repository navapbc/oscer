# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataIntegration::BaseService do
  let(:adapter) { instance_double(DataIntegration::BaseAdapter) }
  let(:service) { described_class.new(adapter: adapter) }

  let(:test_service_class) do
    Class.new(described_class) do
      def test_handle_error(error)
        handle_integration_error(error)
      end

      def test_service_name
        service_name
      end

      def self.name
        "TestService"
      end
    end
  end
  let(:test_service) { test_service_class.new(adapter: adapter) }

  describe "#initialize" do
    it "sets the adapter" do
      expect(service.instance_variable_get(:@adapter)).to eq(adapter)
    end
  end

  describe "#handle_integration_error" do
    let(:error) { StandardError.new("something went wrong") }

    before do
      allow(Rails.logger).to receive(:warn)
    end

    it "logs a warning with the service name and error message" do
      test_service.test_handle_error(error)
      expect(Rails.logger).to have_received(:warn).with("TestService check failed: something went wrong")
    end

    it "returns nil" do
      expect(test_service.test_handle_error(error)).to be_nil
    end
  end

  describe "#service_name" do
    it "returns the demodulized class name" do
      expect(test_service.test_service_name).to eq("TestService")
    end
  end
end
