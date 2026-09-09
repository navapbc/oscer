# Staff certification case income (OSCER-408)

Implementation for staff case income lines and compliance summaries uses **`ExternalActivity`** (income-bearing rows) scoped by member and the certification **continuous lookback** (see `CertificationCasesController#fetch_external_income_activities` and `IncomeComplianceDeterminationService`).

GitHub issue [#408](https://github.com/navapbc/oscer/issues/408) originally referenced `Income.for_member`; the shipped query is **`ExternalActivity.for_member(...).within_period(lookback_period).with_income`** (external hours use the same query with `.with_hours`). Prefer this stack for any follow-up work so intake and staff UI stay consistent.

See also: `docs/architecture/income-data/income-data.md`.
