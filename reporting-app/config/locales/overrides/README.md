# Locale overrides (deployment-owned)

Drop YAML files in this directory to override OSCER's locale strings. Files
use standard Rails I18n YAML format and the same locale codes OSCER ships
(`en`, `es-US`).

## Recommended: mirror OSCER's directory structure

```
config/locales/overrides/
├── views/
│   └── application/
│       ├── my-state.en.yml
│       └── my-state.es-US.yml
└── models/
    └── user/
        └── my-state.en.yml
```

Mirroring makes it visually clear which OSCER file each override shadows:

```yaml
# config/locales/overrides/views/application/my-state.en.yml
en:
  views:
    application:
      title: "MyState Community Engagement Reporting"
```

Flat layout (single file at the top level of `overrides/`) is also fine for
deployments with only a handful of overrides — Rails I18n is location-agnostic;
directory path doesn't scope keys. Use whatever stays readable as your
override set grows.

## How precedence works

OSCER's `config/application.rb` loads files under `overrides/` AFTER all base
locale files in `I18n.load_path`, so override keys always win on conflict.
The ordering is explicit — adding new locale subdirectories to OSCER core
will not affect override precedence.

See `CUSTOMIZATION.md` (Locales and branding) for the broader customization context.
