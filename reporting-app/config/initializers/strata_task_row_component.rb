# frozen_string_literal: true

# Staff::TaskRowComponent subclasses Strata::Tasks::TaskRowComponent from the engine. In some
# boot orders (e.g. first reference from TasksController#tasks_index_locals), Zeitwerk can
# autoload the subclass before the engine defines Strata::Tasks, causing
# "uninitialized constant Strata::Tasks". Preload the parent once the gem is on the load path.
Rails.application.config.to_prepare do
  spec = Gem.loaded_specs["strata"]
  next unless spec

  path = File.join(spec.full_gem_path, "app/components/strata/tasks/task_row_component.rb")
  require path if File.exist?(path)
end
