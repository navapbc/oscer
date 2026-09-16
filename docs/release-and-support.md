# Release & support policy

This page describes how OSCER is versioned, released, and supported: the
information a state or organization needs to evaluate OSCER as an open-source
product and to plan for keeping a deployment current. It is aimed at adopters
and reviewers; for *how to customize* a deployment see the customization guide
(`reporting-app/CUSTOMIZATION.md`).

> **Status: pre-release.** OSCER has not yet cut its first tagged release
> (tracked in [#531](https://github.com/navapbc/oscer/issues/531)). The
> versioning scheme below is settled; the **release cadence** and notification
> mechanics are stated as intent and will be finalized at the first release.
> _(Update this note at the first release.)_

OSCER is distributed as this open-source repository. A downstream deployment
keeps its own copy and syncs upstream changes in to stay current; the
repository, with its tagged releases, is the unit that is versioned and released.

## License

OSCER is released under the [Apache 2.0 License](https://github.com/navapbc/oscer/blob/main/LICENSE).
States deploy it within their own environment and retain full ownership of the
deployment, configuration, and data; there are no licensing fees.

## Versioning

OSCER uses **calendar-based versioning (CalVer)** with sequential release
numbers, in the form **`vYEAR.SEQUENCE.PATCH`**:

- **`YEAR`**: the calendar year of the release (e.g. `2026`).
- **`SEQUENCE`**: the release number *within* that year, incrementing
  sequentially (`1`, `2`, `3`, …). It is **not** a calendar month.
- **`PATCH`**: incremented for fixes (including security fixes) released
  against an existing version.

For example, `v2026.1.0` is the first release of 2026; `v2026.2.0` is the next;
`v2026.2.1` is a patch on top of it.

Because CalVer carries no semantic "major version" signal, a breaking change
(such as a migration that requires a specific prior version) is called out as a
**required upgrade stop** in the release notes for the gating version: a version
an adopter must land on before continuing past it. The migration convention
(`docs/reporting-app/migrations.md`) applies the same idea on the schema side.

## Releases

Each release is a git tag on the OSCER repository, published as a GitHub Release
with notes describing what changed. A deployment pins to a release and moves
forward by syncing in the corresponding tag.

To follow new releases, watch the OSCER repository on GitHub and choose
**Releases only** (Watch → Custom → Releases). This is GitHub's built-in
notification path; no separate subscription is required.

Release cadence is driven by upstream policy and product change rather than a
fixed calendar. OSCER is designed for frequent policy change, so adopters should
plan to take releases regularly rather than pinning indefinitely to one version.

## Security updates & vulnerability reporting

Security fixes are prioritized and published through the normal release channel,
typically as a patch release against the latest version, and are called out in
the corresponding release notes.

**To report a vulnerability**, follow the [Security Policy](https://github.com/navapbc/oscer/blob/main/SECURITY.md):
email **strata@navapbc.com** with a description and, ideally, a reproduction.
Please do **not** open public GitHub issues for vulnerabilities, and report any
security problem to the team before disclosing it publicly.

For how OSCER manages vulnerabilities in its own pipeline (automated scanning,
dependency monitoring), see [vulnerability management](https://github.com/navapbc/oscer/blob/main/docs/infra/vulnerability-management.md).

## Supported versions

We recommend running the **latest release** to ensure you receive all security
and bug fixes. Adopters are responsible for scanning and patching their own
deployment within their infrastructure, using their own security tooling.

## Staying current

OSCER deployments stay current by syncing upstream changes in. Routing
customizations through the supported override mechanisms keeps those syncs
conflict-free; how that works is documented in the customization guide
(`reporting-app/CUSTOMIZATION.md`).

## Getting help

- **Bugs & feature requests:** [GitHub Issues](https://github.com/navapbc/oscer/issues)
- **Security vulnerabilities:** [Security Policy](https://github.com/navapbc/oscer/blob/main/SECURITY.md) (strata@navapbc.com)
- **Contributing:** [Contributing Guidelines](https://github.com/navapbc/oscer/blob/main/CONTRIBUTING.md)
