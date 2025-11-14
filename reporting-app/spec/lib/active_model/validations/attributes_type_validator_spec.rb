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
  attribute :array, :array, of: ActiveModel::Type::Integer
end

class StrataModelToTestAttrs < Strata::ValueObject
  include ActiveRecord::AttributeMethods::BeforeTypeCast

  validates_with ActiveModel::Validations::AttributesTypeValidator

  strata_attribute :int, :integer
  strata_attribute :str, :string
  strata_attribute :bool, :boolean
  strata_attribute :date, :date
  strata_attribute :union, ModelToTestAttrsOneOrOther.to_type
  strata_attribute :array, :integer, array: true

  # Strata-only attributes
  strata_attribute :address, :address
  strata_attribute :memorable_date, :memorable_date
  strata_attribute :name, :name
  strata_attribute :money, :money
  strata_attribute :date_range, :us_date, range: true
  strata_attribute :tax_id, :tax_id
  strata_attribute :us_date, :us_date
  strata_attribute :year_month, :year_month
  strata_attribute :year_quarter, :year_quarter
end

RSpec.describe ActiveModel::Validations::AttributesTypeValidator do
  [ ModelToTestAttrs, StrataModelToTestAttrs ].each do |test_class|
    describe "#{test_class}" do
      context "when given valid data" do
        it "is valid" do
          expect(test_class.new(int: 1)).to be_valid
        end

        it "is valid - union" do
          expect(test_class.new(union: { "one": 1 })).to be_valid
          expect(test_class.new(union: { "two": "foo" })).to be_valid
        end

        it "allows missing attributes" do
          expect(test_class.new()).to be_valid
        end

        it "allows nil" do
          expect(test_class.new(int: nil)).to be_valid
        end

        it "allows various values for boolean" do
          expect(test_class.new(bool: true)).to be_valid
          expect(test_class.new(bool: "true")).to be_valid
          expect(test_class.new(bool: "on")).to be_valid

          expect(test_class.new(bool: false)).to be_valid
          expect(test_class.new(bool: "false")).to be_valid
          expect(test_class.new(bool: "off")).to be_valid
        end

        it "allows valid dates" do
          expect(test_class.new(date: "2025-10-15")).to be_valid
        end

        it "allows array type - empty" do
          expect(test_class.new(array: [])).to be_valid
        end

        it "allows array type - not empty" do
          expect(test_class.new(array: [ 1 ])).to be_valid
        end
      end

      context "when given invalid data" do
        it "is not valid - empty hash" do
          expect(test_class.new(int: {})).not_to be_valid
        end

        it "is not valid - symbol" do
          expect(test_class.new(int: :bar)).not_to be_valid
        end

        it "is not valid - union" do
          expect(test_class.new(union: { "three": 3 })).not_to be_valid
        end

        it "is not valid - boolean value" do
          expect(test_class.new(bool: 5)).not_to be_valid
          expect(test_class.new(bool: "this should not be true")).not_to be_valid
          expect(test_class.new(bool: {})).not_to be_valid
        end

        it "is not valid - date" do
          expect(test_class.new(date: "3")).not_to be_valid
          expect(test_class.new(date: 3)).not_to be_valid
        end
      end

      context "with special string handling" do
        it "rejects numbers" do
          expect(test_class.new(str: 1)).not_to be_valid
        end

        it "rejects symbols" do
          expect(test_class.new(str: :foo)).not_to be_valid
        end

        it "rejects empty hash" do
          expect(test_class.new(str: {})).not_to be_valid
        end

        it "rejects objects" do
          expect(test_class.new(str: Class.new())).not_to be_valid
        end
      end

      context "with special integer handling" do
        it "rejects strings" do
          expect(test_class.new(int: "bar")).not_to be_valid
        end

        it "rejects boolean" do
          expect(test_class.new(int: true)).not_to be_valid
          expect(test_class.new(int: false)).not_to be_valid
        end
      end

      context "with array type handling" do
        it "rejects if only invalid values" do
          expect(test_class.new(array: [ "foo", "bar" ])).not_to be_valid
        end

        it "rejects if partial invalid values" do
          expect(test_class.new(array: [ 1, "bar" ])).not_to be_valid
        end
      end
    end
  end

  describe "Strata special attribute types" do
    context "with address" do
      it "allows valid" do
        expect(StrataModelToTestAttrs.new(address: {
          "street_line_1": "123 Main St.",
          "street_line_2": "Apt 321",
          "city": "Small town",
          "state": "KS",
          "zip_code": "67202"
        })).to be_valid
        # TODO: can't find the factory?
        # expect(StrataModelToTestAttrs.new(address: build(:address).to_json)).to be_valid
      end

      it "rejects invalid" do
        expect(StrataModelToTestAttrs.new(address: {
          "street_line_1": 123
        })).not_to be_valid
        # TODO: can't find the factory?
        # expect(StrataModelToTestAttrs.new(address: build(:address, :invalid).to_json)).not_to be_valid
      end
    end

    context "with memorable date" do
      it "allows valid" do
        expect(StrataModelToTestAttrs.new(memorable_date: "2025-10-27")).to be_valid
      end

      it "rejects invalid" do
        expect(StrataModelToTestAttrs.new(memorable_date: "foo")).not_to be_valid
      end
    end

    context "with name" do
      it "allows valid" do
        expect(StrataModelToTestAttrs.new(name: { "first": "Jane", "last": "Doe" })).to be_valid
      end

      it "rejects invalid - non-object" do
        expect(StrataModelToTestAttrs.new(name: 123)).not_to be_valid
      end

      it "rejects invalid - non-string values" do
        expect(StrataModelToTestAttrs.new(name: { "first": 1 })).not_to be_valid
      end
    end

    context "with money" do
      it "allows valid" do
        expect(StrataModelToTestAttrs.new(money: 100)).to be_valid
      end

      it "rejects invalid" do
        expect(StrataModelToTestAttrs.new(money: "foo")).not_to be_valid
      end
    end

    context "with date_range" do
      it "allows valid" do
        expect(StrataModelToTestAttrs.new(date_range: { "start": Date.new(2025, 10, 27), "end": Date.new(2025, 10, 28) })).to be_valid
      end

      it "rejects invalid" do
        expect(StrataModelToTestAttrs.new(date_range: "foo")).not_to be_valid
      end
    end

    context "with tax_id" do
      it "allows valid" do
        expect(StrataModelToTestAttrs.new(tax_id: "123456789")).to be_valid
      end

      it "rejects invalid" do
        expect(StrataModelToTestAttrs.new(tax_id: "foo")).not_to be_valid
      end
    end

    context "with us_date" do
      it "allows valid" do
        expect(StrataModelToTestAttrs.new(us_date: Date.new(2025, 10, 27))).to be_valid
      end

      it "rejects invalid" do
        expect(StrataModelToTestAttrs.new(us_date: "foo")).not_to be_valid
      end
    end

    context "with year_month" do
      it "allows valid" do
        expect(StrataModelToTestAttrs.new(year_month: "2025-10")).to be_valid
      end

      it "rejects invalid" do
        expect(StrataModelToTestAttrs.new(year_month: "foo")).not_to be_valid
      end
    end

    context "with year_quarter" do
      it "allows valid" do
        expect(StrataModelToTestAttrs.new(year_quarter: "2025Q1")).to be_valid
      end

      it "rejects invalid" do
        expect(StrataModelToTestAttrs.new(year_quarter: "foo")).not_to be_valid
      end
    end
  end
end
