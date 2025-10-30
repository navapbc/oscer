# frozen_string_literal: true

class LocaleGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)

  def create_model_locale_file
    template "model_locale.yml", "config/locales/models/#{file_name}/en.yml"
  end

  def create_view_locale_file
    template "view_locale.yml", "config/locales/views/#{plural_file_name}/en.yml"
  end

  private

  def file_name
    name.underscore
  end

  def plural_file_name
    file_name.pluralize
  end
end
