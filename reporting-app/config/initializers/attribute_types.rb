# frozen_string_literal: true

ActiveSupport.on_load(:active_model) do
  ActiveModel::Type.register(:array, ArrayType)
  ActiveModel::Type.register(:enum, EnumType)
end
