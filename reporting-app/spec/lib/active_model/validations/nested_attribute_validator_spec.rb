# frozen_string_literal: true

require 'rails_helper'

class ValueToTestNested
  include ActiveModel::Model
  include ActiveModel::Attributes

  validates_with ActiveModel::Validations::NestedAttributeValidator

  attribute :dates, :array, of: ActiveModel::Type::Date.new
end

class SimpleModelNested
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :foo, :string

  validates :foo, presence: true
end

RSpec.describe ActiveModel::Validations::NestedAttributeValidator do
  context "when given valid data" do
    it "is valid - empty array" do
      expect(ValueToTestNested.new(dates: [])).to be_valid
    end

    it "is valid - array with values" do
      expect(ValueToTestNested.new(dates: [ Date.new(2025, 10, 21) ])).to be_valid
    end
  end

  context "when given invalid data" do
    it "does not error on simple types" do
      expect(ValueToTestNested.new(dates: [ "bar" ])).to be_valid
    end

    it "does error on things with validation" do
      expect(ValueToTestNested.new(dates: [ SimpleModelNested.new() ])).not_to be_valid
    end
  end
end
