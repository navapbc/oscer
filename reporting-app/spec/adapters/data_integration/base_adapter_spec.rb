# frozen_string_literal: true

require "rails_helper"

class TestAdapter < DataIntegration::BaseAdapter
  attr_reader :before_hook_called, :after_hook_called, :last_response, :hooks_called

  before_request :my_before_hook
  before_request :another_before_hook
  after_request :my_after_hook

  def initialize(connection: nil)
    super
    @hooks_called = []
  end

  def call_api(connection)
    with_error_handling do
      connection.get("/test")
    end
  end

  protected

  def default_connection
    Faraday.new(url: "http://api.example.com") do |f|
      f.adapter :test do |stub|
        stub.get("/test") { [ 200, {}, "success" ] }
      end
    end
  end

  def handle_server_error(response)
    raise DataIntegration::BaseAdapter::ServerError, "Custom server error: #{response.status}"
  end

  private

  def my_before_hook
    @before_hook_called = true
    @hooks_called << :my_before_hook
  end

  def another_before_hook
    @hooks_called << :another_before_hook
  end

  def my_after_hook(response)
    @after_hook_called = true
    @last_response = response
  end
end

RSpec.describe DataIntegration::BaseAdapter do
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:connection) do
    Faraday.new do |f|
      f.adapter :test, stubs
    end
  end
  let(:adapter) { TestAdapter.new(connection: connection) }

  describe "initialization" do
    it "uses the provided connection" do
      expect(adapter.instance_variable_get(:@connection)).to eq(connection)
    end

    it "raises NotImplementedError if default_connection is not overridden" do
      base_adapter = described_class.allocate
      expect { base_adapter.send(:default_connection) }.to raise_error(NotImplementedError)
    end
  end

  describe "hooks" do
    let(:sub_test_adapter) { Class.new(TestAdapter) }

    it "runs all before_request hooks in order" do
      stubs.get("/test") { [ 200, {}, "ok" ] }
      adapter.call_api(connection)
      expect(adapter.before_hook_called).to be true
      expect(adapter.hooks_called).to eq([ :my_before_hook, :another_before_hook ])
    end

    it "runs after_request hooks with the response" do
      stubs.get("/test") { [ 200, {}, "ok" ] }
      adapter.call_api(connection)
      expect(adapter.after_hook_called).to be true
      expect(adapter.last_response.status).to eq(200)
    end

    it "inherits hooks from parent class" do
      expect(sub_test_adapter.before_request_hooks).to include(:my_before_hook, :another_before_hook)
      expect(sub_test_adapter.after_request_hooks).to include(:my_after_hook)
    end
  end

  describe "error handling" do
    context "when response is 2xx" do
      it "returns the response body" do
        stubs.get("/test") { [ 200, {}, "success body" ] }
        expect(adapter.call_api(connection)).to eq("success body")
      end
    end

    context "when response is 401 Unauthorized" do
      it "raises UnauthorizedError" do
        stubs.get("/test") { [ 401, {}, "" ] }
        expect { adapter.call_api(connection) }
          .to raise_error(DataIntegration::BaseAdapter::UnauthorizedError, /unauthorized/)
      end
    end

    context "when response is 429 Rate Limited" do
      it "raises RateLimitError" do
        stubs.get("/test") { [ 429, {}, "" ] }
        expect { adapter.call_api(connection) }
          .to raise_error(DataIntegration::BaseAdapter::RateLimitError, /rate limited/)
      end
    end

    context "when response is 5xx Server Error" do
      it "uses the overridden handle_server_error method" do
        stubs.get("/test") { [ 500, {}, "" ] }
        expect { adapter.call_api(connection) }
          .to raise_error(DataIntegration::BaseAdapter::ServerError, "Custom server error: 500")
      end
    end

    context "when response is other error status" do
      it "raises ApiError" do
        stubs.get("/test") { [ 404, {}, "" ] }
        expect { adapter.call_api(connection) }
          .to raise_error(DataIntegration::BaseAdapter::ApiError, /error: 404/)
      end
    end

    context "when a Faraday error occurs" do
      it "raises ApiError with connection error message" do
        stubs.get("/test") { raise Faraday::ConnectionFailed, "failed" }
        expect { adapter.call_api(connection) }
          .to raise_error(DataIntegration::BaseAdapter::ApiError, /connection error: failed/)
      end
    end
  end

  describe "#adapter_name" do
    it "returns the class name without modules" do
      # Use a named class instead of an anonymous one to avoid nil name
      class DataIntegration::MyTestAdapter < DataIntegration::BaseAdapter; end
      adapter = DataIntegration::MyTestAdapter.new(connection: connection)
      expect(adapter.send(:adapter_name)).to eq("MyTestAdapter")
    end
  end
end
