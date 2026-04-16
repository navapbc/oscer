# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StaffHelper, type: :helper do
  describe "median_time_to_close" do
    it "returns 0 when no data" do
      result = helper.median_time_to_close({})
      expect(result).to eq 'Median time to close: no data'
    end

    it "returns single form when 1 day" do
      result = helper.median_time_to_close({ time_to_close_seconds: 1.day })
      expect(result).to eq 'Median time to close: 1 day'
    end

    it "returns plural form when greater than 1 day" do
      result = helper.median_time_to_close({ time_to_close_seconds: 2.days })
      expect(result).to eq 'Median time to close: 2 days'
    end

    it "returns hours when less than 1 day" do
      result = helper.median_time_to_close({ time_to_close_seconds: 4.hours })
      expect(result).to eq 'Median time to close: 4 hours'
    end

    it "returns hour when single hour" do
      result = helper.median_time_to_close({ time_to_close_seconds: 1.hour })
      expect(result).to eq 'Median time to close: 1 hour'
    end
  end
end
