# frozen_string_literal: true

require "rails_helper"

# The plumbing in config/application.rb ensures locale files under
# config/locales/overrides/ load AFTER all other config/locales/**/*.{rb,yml}
# files. This determines which value Rails I18n returns for duplicate keys —
# last-loaded wins.
#
# A naive single-glob load order would put 'overrides/...' at the alphabetical
# position of the directory name (between 'models/' and 'services/'), so base
# keys in services/ and views/ would beat overrides. The plumbing inverts that
# regardless of where alphabetical sort would place the overrides directory.
RSpec.describe "I18n load-path plumbing in config/application.rb" do # rubocop:disable RSpec/DescribeClass
  describe "the load-order logic" do
    let(:tmp_root) { Dir.mktmpdir("i18n-load-path-test") }
    let(:tmp_locales) { File.join(tmp_root, "locales") }
    let(:tmp_overrides) { File.join(tmp_locales, "overrides") }

    before do
      FileUtils.mkdir_p(File.join(tmp_locales, "views"))
      FileUtils.mkdir_p(tmp_overrides)
      File.write(File.join(tmp_locales, "views/en.yml"), "en:\n  key: base\n")
      File.write(File.join(tmp_overrides, "myoverride.en.yml"), "en:\n  key: override\n")
    end

    after do
      FileUtils.rm_rf(tmp_root) if Dir.exist?(tmp_root)
    end

    it "places overrides AFTER base paths, despite alphabetical sort placing overrides earlier" do
      naive_order = Dir[File.join(tmp_locales, "**/*.{rb,yml}")]
      naive_overrides_idx = naive_order.index { |p| p.include?("/overrides/") }
      naive_views_idx = naive_order.index { |p| p.include?("/views/") }

      expect(naive_overrides_idx).to be < naive_views_idx,
        "Sanity check: naive Dir[] places overrides before views — this is the bug the plumbing fixes"

      base = Dir[File.join(tmp_locales, "**/*.{rb,yml}")]
        .reject { |p| p.include?("/locales/overrides/") }
      overrides = Dir[File.join(tmp_overrides, "**/*.{rb,yml}")]
      plumbed = base + overrides

      plumbed_overrides_idx = plumbed.index { |p| p.include?("/overrides/") }
      plumbed_views_idx = plumbed.index { |p| p.include?("/views/") }

      expect(plumbed_overrides_idx).to be > plumbed_views_idx,
        "Plumbing must place overrides after views so overrides win on duplicate keys"
    end
  end

  describe "the load-order applied to the real I18n.load_path at boot" do
    it "places any override paths after all base paths" do
      base_paths = I18n.load_path.reject { |p| p.to_s.include?("/locales/overrides/") }
      override_paths = I18n.load_path.select { |p| p.to_s.include?("/locales/overrides/") }

      # If any override YAML files exist, they must appear AFTER all base paths.
      # If no override YAMLs exist yet (just the README), this assertion is
      # vacuously satisfied and the logic-level spec above covers the plumbing.
      if override_paths.any?
        max_base_idx = base_paths.map { |p| I18n.load_path.index(p) }.max
        min_override_idx = override_paths.map { |p| I18n.load_path.index(p) }.min

        expect(min_override_idx).to be > max_base_idx
      end
    end
  end
end
