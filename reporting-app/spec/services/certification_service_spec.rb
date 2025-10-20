# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CertificationService do
  let(:service) { described_class.new }
  let(:closed_case) { create(:certification_case, :with_closed_status) }

  before do
    closed_case
  end

  describe '#fetch_open_actionable_cases' do
    let(:actionable_case) { create(:certification_case, :actionable) }
    let(:non_actionable_case) { create(:certification_case) }

    before do
      actionable_case
      non_actionable_case
    end

    it 'returns only open actionable cases' do
      result = service.fetch_open_actionable_cases

      expect(result).to contain_exactly(actionable_case)
    end

    it 'does not return closed cases' do
      result = service.fetch_open_actionable_cases

      expect(result).not_to include(closed_case)
    end

    it 'does not return non-actionable cases' do
      result = service.fetch_open_actionable_cases

      expect(result).not_to include(non_actionable_case)
    end

    it 'hydrates cases with their certifications' do
      result = service.fetch_open_actionable_cases.first

      expect(result.certification).to be_present
    end
  end

  describe '#fetch_closed_cases' do
    let(:open_case) { create(:certification_case) }

    before do
      open_case
    end

    it 'returns only closed cases with their certifications hydrated' do
      result = service.fetch_closed_cases

      expect(result).to contain_exactly(closed_case)
    end

    it 'does not return open cases' do
      result = service.fetch_closed_cases

      expect(result).not_to include(open_case)
    end
  end
end
