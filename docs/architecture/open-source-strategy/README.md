# OSCER Open Source Strategy

How OSCER is published as a [Copier](https://copier.readthedocs.io/) template, versioned, and kept current by state implementers via the `nava-platform` CLI — and how a deployment customizes OSCER **without forking**.

These documents are the **canonical source** going forward. Update them here as the implementation evolves; they are delivered through epic [#527](https://github.com/navapbc/oscer/issues/527) (strategy detail in [#213](https://github.com/navapbc/oscer/issues/213)).

| Document | What it covers |
|---|---|
| [update-strategy.md](./update-strategy.md) | The strategy: the Copier-template repository model, the four-tier customization ladder, the Extension Contract, CalVer release strategy, and the implementation roadmap. |
| [customize-and-extend.md](./customize-and-extend.md) | The implementation-detail companion: file-level customization mechanics across the layers (config, locales, branding, services/rulesets, models), the Extension Contract paths, and the implementer install/update workflow. |

Tiers and Layers are two views of the same material: the strategy doc and `CUSTOMIZATION.md` use a four-**tier** ladder, `customize-and-extend.md` uses five **layers**. Tier 1 maps to Layer 1, Tier 2 to Layers 2-3, and Tier 4 to Layers 4-5; Tier 3 (generators) is proposed-only, with no implemented layer yet.

> **Status:** Living documents. Sections describing shipped infrastructure (Tier 1/2 config, Layer 4/5 scaffolds) reflect current `main`; roadmap items describe planned work tracked in [#527](https://github.com/navapbc/oscer/issues/527).
