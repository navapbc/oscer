# frozen_string_literal: true

class Users::AuthAppCodeForm
  include ActiveModel::Model

  attr_accessor :code

  validates :code, length: { is: 6 }
end
