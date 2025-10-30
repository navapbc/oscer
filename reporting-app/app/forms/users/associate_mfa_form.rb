# frozen_string_literal: true

class Users::AssociateMfaForm
  include ActiveModel::Model

  attr_accessor :temporary_code

  validates :temporary_code, length: { is: 6 }
end
