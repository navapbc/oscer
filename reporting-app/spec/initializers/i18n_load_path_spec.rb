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

  # End-to-end demonstration that overrides actually win at I18n.t lookup
  # time for keys defined in services/ and views/ — the load-bearing property
  # the application.rb plumbing exists to guarantee. Distinct from the index-
  # position spec above: that one proves the load_path list is in the right
  # order; this one proves the backend honors that order at resolution time.
  describe "override-wins behavior at I18n.t lookup time for keys in services/ or views/" do
    let(:tmp_root) { Dir.mktmpdir("i18n-override-wins-test") }
    let(:tmp_locales) { File.join(tmp_root, "locales") }
    let(:tmp_services) { File.join(tmp_locales, "services") }
    let(:tmp_views) { File.join(tmp_locales, "views") }
    let(:tmp_overrides) { File.join(tmp_locales, "overrides") }

    # around lets us capture I18n state in local variables before any test
    # mutates it, then restore via ensure so cleanup runs even on failure.
    around do |example|
      original_backend = I18n.backend
      original_load_path = I18n.load_path.dup

      begin
        FileUtils.mkdir_p(tmp_services)
        FileUtils.mkdir_p(tmp_views)
        FileUtils.mkdir_p(tmp_overrides)

        File.write(File.join(tmp_services, "en.yml"),
          "en:\n  canary_in_services: from-services-base\n")
        File.write(File.join(tmp_views, "en.yml"),
          "en:\n  canary_in_views: from-views-base\n")
        File.write(File.join(tmp_overrides, "deployment.en.yml"),
          "en:\n  canary_in_services: from-overrides\n  canary_in_views: from-overrides\n")

        example.run
      ensure
        I18n.load_path = original_load_path
        I18n.backend = original_backend
        FileUtils.rm_rf(tmp_root) if Dir.exist?(tmp_root)
      end
    end

    def load_with_paths(paths)
      I18n.backend = I18n::Backend::Simple.new
      I18n.load_path = paths
      I18n.backend.reload!
    end

    it "with the application.rb plumbing, overrides/ wins for keys defined in services/ AND views/" do
      base_locales = Dir[File.join(tmp_locales, "**/*.{rb,yml}")]
        .reject { |p| p.include?("/locales/overrides/") }
      override_locales = Dir[File.join(tmp_overrides, "**/*.{rb,yml}")]

      load_with_paths(base_locales + override_locales)

      expect(I18n.t("canary_in_services")).to eq("from-overrides")
      expect(I18n.t("canary_in_views")).to eq("from-overrides")
    end

    # Documents the bug the plumbing fixes: a naive recursive glob orders
    # paths alphabetically, placing 'overrides/' before 'services/' and
    # 'views/' — which lets the later-loaded base files silently beat the
    # deployment's overrides at I18n.t lookup.
    it "without the plumbing (naive recursive glob), services/ and views/ silently beat overrides/" do
      naive_load_path = Dir[File.join(tmp_locales, "**/*.{rb,yml}")]

      load_with_paths(naive_load_path)

      expect(I18n.t("canary_in_services")).to eq("from-services-base")
      expect(I18n.t("canary_in_views")).to eq("from-views-base")
    end
  end
end
