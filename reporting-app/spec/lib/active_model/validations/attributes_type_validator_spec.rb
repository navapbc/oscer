# frozen_string_literal: true

require 'rails_helper'

class ModelToTestAttrsOne < ValueObject
  include ActiveModel::AsJsonAttributeType

  attribute :one, :integer

  validates :one, presence: true
end

class ModelToTestAttrsOther < ValueObject
  include ActiveModel::AsJsonAttributeType

  attribute :two, :string

  validates :two, presence: true
end

class ModelToTestAttrsOneOrOther < UnionObject
  include ActiveModel::AsJsonAttributeType

  def self.union_types
    [ ModelToTestAttrsOne, ModelToTestAttrsOther ]
  end
end

class ModelToTestAttrs
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveRecord::AttributeMethods::BeforeTypeCast

  validates_with ActiveModel::Validations::AttributesTypeValidator

  attribute :int, :integer
  attribute :str, :string
  attribute :bool, :boolean
  attribute :date, :date
  attribute :union, ModelToTestAttrsOneOrOther.to_type
  attribute :array, :array, of: ActiveModel::Type::Integer.new
end
end

RSpec.describe ActiveModel::Validations::AttributesTypeValidator do
  context "when given valid data" do
    it "is valid" do
      expect(ModelToTestAttrs.new(int: 1)).to be_valid
    end

    it "is valid - union" do
      expect(ModelToTestAttrs.new(union: { "one": 1 })).to be_valid
      expect(ModelToTestAttrs.new(union: { "two": "foo" })).to be_valid
    end

    it "allows missing attributes" do
      expect(ModelToTestAttrs.new()).to be_valid
    end

    it "allows nil" do
      expect(ModelToTestAttrs.new(int: nil)).to be_valid
    end

    it "allows various values for boolean" do
      expect(ModelToTestAttrs.new(bool: true)).to be_valid
      expect(ModelToTestAttrs.new(bool: "true")).to be_valid
      expect(ModelToTestAttrs.new(bool: "on")).to be_valid

      expect(ModelToTestAttrs.new(bool: false)).to be_valid
      expect(ModelToTestAttrs.new(bool: "false")).to be_valid
      expect(ModelToTestAttrs.new(bool: "off")).to be_valid
    end

    it "allows valid dates" do
      expect(ModelToTestAttrs.new(date: "2025-10-15")).to be_valid
    end

    it "allows array type - empty" do
      expect(ModelToTestAttrs.new(array: [])).to be_valid
    end

    it "allows array type - not empty" do
      expect(ModelToTestAttrs.new(array: [ 1 ])).to be_valid
    end
  end

  context "when given invalid data" do
    it "is not valid - empty hash" do
      expect(ModelToTestAttrs.new(int: {})).not_to be_valid
    end

    it "is not valid - symbol" do
      expect(ModelToTestAttrs.new(int: :bar)).not_to be_valid
    end

    it "is not valid - union" do
      expect(ModelToTestAttrs.new(union: { "three": 3 })).not_to be_valid
    end

    it "is not valid - boolean value" do
      expect(ModelToTestAttrs.new(bool: 5)).not_to be_valid
      expect(ModelToTestAttrs.new(bool: "this should not be true")).not_to be_valid
      expect(ModelToTestAttrs.new(bool: {})).not_to be_valid
    end

    it "is not valid - date" do
      expect(ModelToTestAttrs.new(date: "3")).not_to be_valid
      expect(ModelToTestAttrs.new(date: 3)).not_to be_valid
    end
  end

  context "with special string handling" do
    it "rejects numbers" do
      expect(ModelToTestAttrs.new(str: 1)).not_to be_valid
    end

    it "rejects symbols" do
      expect(ModelToTestAttrs.new(str: :foo)).not_to be_valid
    end

    it "rejects empty hash" do
      expect(ModelToTestAttrs.new(str: {})).not_to be_valid
    end

    it "rejects objects" do
      expect(ModelToTestAttrs.new(str: Class.new())).not_to be_valid
    end
  end

  context "with special integer handling" do
    it "rejects strings" do
      expect(ModelToTestAttrs.new(int: "bar")).not_to be_valid
    end

    it "rejects boolean" do
      expect(ModelToTestAttrs.new(int: true)).not_to be_valid
      expect(ModelToTestAttrs.new(int: false)).not_to be_valid
    end
  end

  context "with array type handling" do
    it "rejects if only invalid values" do
      expect(ModelToTestAttrs.new(array: [ "foo", "bar" ])).not_to be_valid
    end

    it "rejects if partial invalid values" do
      expect(ModelToTestAttrs.new(array: [ 1, "bar" ])).not_to be_valid
    end
  end
end
