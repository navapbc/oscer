# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Member, type: :model do
  describe '.from_certification' do
    let(:member_data) do
      build(:certification_member_data, :with_full_name)
    end
    let(:certification) do
      create(:certification,
        :with_member_data_base,
        :connected_to_email,
        member_id: "MEMBER123",
        email: "test@example.com",
        member_data_base: member_data
      )
    end

    it 'creates a Member from a Certification' do
      member = described_class.from_certification(certification)

      expect(member.member_id).to eq("MEMBER123")
      expect(member.email).to eq("test@example.com")
      expect(member.name.full_name).to eq("Jane Q Public")
    end
  end

  describe '.find_by_member_id' do
    let(:member_data) { build(:certification_member_data, :with_full_name) }

    before do
      create(:certification,
        :with_member_data_base,
        :connected_to_email,
        member_id: "MEMBER123",
        email: "test@example.com",
        member_data_base: member_data
      )
    end

    it 'finds a member by member_id' do
      member = described_class.find_by_member_id("MEMBER123")

      expect(member.member_id).to eq("MEMBER123")
      expect(member.email).to eq("test@example.com")
      expect(member.name.full_name).to eq("Jane Q Public")
    end
  end

  describe '.search_by_email' do
    let(:member_data_one) { build(:certification_member_data, :with_full_name) }
    let(:member_data_two) { build(:certification_member_data, :with_name_parts) }

    before do
      create(:certification,
        :with_member_data_base,
        :connected_to_email,
        member_id: "MEMBER1",
        email: "test@example.com",
        member_data_base: member_data_one
      )

      create(:certification,
        :with_member_data_base,
        :connected_to_email,
        member_id: "MEMBER2",
        email: "test@example.com",
        member_data_base: member_data_two
      )
    end

    it 'finds all members with matching email' do
      members = described_class.search_by_email("test@example.com")

      expect(members.length).to eq(2)
      expect(members.map(&:member_id)).to contain_exactly("MEMBER1", "MEMBER2")
      expect(members.map { |m| m.name.full_name }).to contain_exactly("Jane Q Public", "John Doe")
    end
  end
end
