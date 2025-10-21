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

  attribute :foo, :integer
  attribute :union, ModelToTestAttrsOneOrOther.to_type
end

RSpec.describe ActiveModel::Validations::AttributesTypeValidator do
  context "when given valid data" do
    it "is valid" do
      expect(ModelToTestAttrs.new(foo: 1)).to be_valid
    end

    it "is valid - union" do
      expect(ModelToTestAttrs.new(union: { "one": 1 })).to be_valid
      expect(ModelToTestAttrs.new(union: { "two": "foo" })).to be_valid
    end
  end

  context "when given invalid data" do
    it "is not valid - empty hash" do
      expect(ModelToTestAttrs.new(foo: {})).not_to be_valid
    end

    it "is not valid - symbol" do
      expect(ModelToTestAttrs.new(foo: :bar)).not_to be_valid
    end

    it "is not valid - string" do
      expect(ModelToTestAttrs.new(foo: "bar")).not_to be_valid
    end

    it "is not valid - union" do
      expect(ModelToTestAttrs.new(union: { "three": 3 })).not_to be_valid
    end
  end
end
