# frozen_string_literal: true

# API clients authenticate as Api::Client, not a User.
# API uploads have uploader_id: nil, source_type: :api.
class MakeUploaderIdNullableForApiUploads < ActiveRecord::Migration[7.2]
  def change
    change_column_null :certification_batch_uploads, :uploader_id, true
  end
end
