# frozen_string_literal: true

class ChangeIncomeMemberIdCommentFromExParteActivityToExternalHourlyActivity < ActiveRecord::Migration[8.0]
  def change
    change_column_comment(
      :incomes,
      :member_id,
      from: "Member reference - always required (parallel to ExParteActivity; no certification FK)",
      to: "Member reference - always required (parallel to ExternalHourlyActivity; no certification FK)")
  end
end
