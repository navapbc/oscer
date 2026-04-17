# Follow-up: Ex parte CE business process (hours + income orchestration)

This note is for the **next story** that wires **income** into the same ex parte community engagement step as **hours** and advances `CertificationCase` via Strata when income events fire.

## What already exists (OSCER-445 slice)

- **`IncomeComplianceDeterminationService#determine`** publishes **income-specific** events only:
  - `DeterminedIncomeMet`
  - `DeterminedIncomeInsufficient` (payload includes `income_data`)
  - `DeterminedIncomeActionRequired`
- **`NotificationsEventListener`** subscribes to those events and maps them to mailers (`compliant_email`, `action_required_email`, `insufficient_income_email` with `income_data` / `target_income`).
- **`CertificationBusinessProcess`** still runs **`HoursComplianceDeterminationService.determine`** at `ex_parte_community_engagement_check` only (same as before). Income `determine` is **not** invoked by the BP yet—callers are tests and any code that explicitly invokes it.

## Prompt you can paste for the next implementation

```text
Implement ex parte CE business-process orchestration for hours + income in oscer reporting-app.

Context:
- Income path already publishes DeterminedIncomeMet / DeterminedIncomeInsufficient / DeterminedIncomeActionRequired from IncomeComplianceDeterminationService#determine and NotificationsEventListener already subscribes (see current main + OSCER-445).
- Hours path still uses HoursComplianceDeterminationService#determine publishing DeterminedHoursMet / DeterminedHoursInsufficient / DeterminedActionRequired.
- CertificationBusinessProcess currently only calls HoursComplianceDeterminationService at EX_PARTE_COMMUNITY_ENGAGEMENT_CHECK_STEP.

Requirements (align with product):
- Define when to run hours vs income vs both, and which Strata events drive transitions (may unify or keep parallel transitions—follow existing Strata patterns).
- Add CertificationBusinessProcess transitions for income events if not present, and wire system_process to call the right service(s) without duplicate closes or dropped notifications.
- Update specs (business process + services) and any docs (e.g. docs/architecture/income-data/income-data.md, CLAUDE.md bounded context if needed).

Run from reporting-app/: make lint, make test. Prefer Docker Make per project rules.
```

## Optional reference

A prior exploratory branch implemented a unified `CommunityEngagementDeterminationService` (OR compliance, generic `DeterminedCommunityEngagement*` events). That was **reverted** in favor of this smaller slice; you can still use `git log` / branch history on the OSCER-445 branch to compare approaches if useful.
