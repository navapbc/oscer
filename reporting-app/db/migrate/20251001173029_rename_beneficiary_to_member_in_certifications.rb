# frozen_string_literal: true

class RenameBeneficiaryToMemberInCertifications < ActiveRecord::Migration[7.2]
  def change
    rename_column :certifications, :beneficiary_id, :member_id
    rename_column :certifications, :beneficiary_data, :member_data
  end
end
