# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Certification, type: :model do
  describe 'after_create_commit callback' do
    it 'publishes CertificationCreated event with certification_id' do
      allow(Strata::EventManager).to receive(:publish)
      certification = build(:certification)

      certification.save!
      expect(Strata::EventManager).to have_received(:publish).with(
        'CertificationCreated',
        { certification_id: certification.id }
      )
    end
  end

  describe 'member name accessors' do
    context 'with structured name data' do
      let(:certification) do
        build(:certification, member_data: {
          "name" => {
            "first" => "Jane",
            "middle" => "Q",
            "last" => "Public",
            "suffix" => "Jr"
          }
        })
      end

      it 'returns full name from structured data' do
        expect(certification.member_name.full_name).to eq("Jane Q Public Jr")
      end
    end

    context 'with no member_data' do
      let(:certification) { build(:certification, member_data: nil) }

      it 'returns nil for full name' do
        expect(certification.member_name).to be_nil
      end
    end
  end
end
