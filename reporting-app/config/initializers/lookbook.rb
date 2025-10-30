# frozen_string_literal: true

Rails.application.configure do
  config.lookbook.preview_paths = [ Rails.root.join("app", "previews") ]
end
