# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DateUtils do
  describe "month_difference" do
    it "handles start before end" do
        expect(described_class.month_difference(Date.new(2025, 10, 1), Date.new(2025, 12, 1))).to be(2)
    end

    it "handles end before start" do
        expect(described_class.month_difference(Date.new(2025, 12, 1), Date.new(2025, 10, 1))).to be(-2)
    end

    it "handles start==end" do
        expect(described_class.month_difference(Date.new(2025, 10, 1), Date.new(2025, 10, 1))).to be(0)
    end

    it "handles years" do
        expect(described_class.month_difference(Date.new(2024, 10, 1), Date.new(2025, 12, 1))).to be(14)
    end
  end
end
