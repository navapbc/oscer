# frozen_string_literal: true

require 'rails_helper'

class ModelToTestJson
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :str, :string
  attribute :int, :integer
  attribute :hash, ActiveModel::Type::Json.new(Hash)
end

RSpec.describe ActiveModel::Type::Json do
  context "with string type" do
    let(:data) { "foo" }

    it "deserialization" do
      expect(described_class.new(String).deserialize(data.to_json)).to eq(data)
    end

    it "serialization" do
      expect(described_class.new(String).serialize(data)).to eq(data.to_json)
    end

    it "cast" do
      expect(described_class.new(String).cast(data.as_json)).to eq(data)
    end
  end

  context "with integer type" do
    let(:data) { 5 }

    it "deserialization" do
      expect(described_class.new(Integer).deserialize(data.to_json)).to eq(data)
    end

    it "serialization" do
      expect(described_class.new(Integer).serialize(data)).to eq(data.to_json)
    end

    it "cast" do
      expect(described_class.new(Integer).cast(data.as_json)).to eq(data)
    end
  end

  context "with array type" do
    let(:data) { [ "foo", "bar" ] }

    it "deserialization" do
      expect(described_class.new(Array).deserialize(data.to_json)).to eq(data)
    end

    it "serialization" do
      expect(described_class.new(Array).serialize(data)).to eq(data.to_json)
    end

    it "cast" do
      expect(described_class.new(Array).cast(data.as_json)).to eq(data)
    end
  end

  context "with hash type" do
    let(:data) { { "foo": "bar" } }

    it "deserialization" do
      expect(described_class.new(Hash).deserialize(data.to_json)).to eq(data.with_indifferent_access)
    end

    it "serialization" do
      expect(described_class.new(Hash).serialize(data)).to eq(data.to_json)
    end

    it "cast" do
      expect(described_class.new(Hash).cast(data.as_json)).to eq(data.with_indifferent_access)
    end
  end

  context "with model type" do
    let(:data) { ModelToTestJson.new(str: "foo", int: 5, hash: { foo: "bar" }) }

    it "deserialization" do
      expect(described_class.new(ModelToTestJson).deserialize(data.to_json)).to have_attributes(**data.attributes)
    end

    it "serialization" do
      expect(described_class.new(ModelToTestJson).serialize(data)).to eq(data.to_json)
    end

    it "cast" do
      expect(described_class.new(ModelToTestJson).cast(data.as_json)).to have_attributes(**data.attributes)
    end
  end
end
