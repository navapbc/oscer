# Ex parte CE business process (hours + income)

## Implemented behavior

- **`ExParteCommunityEngagementDeterminationService.determine`** runs at `ex_parte_community_engagement_check`: evaluates **hours first**; if below the hours threshold, runs **`IncomeComplianceDeterminationService.determine(kase, hours_context: …)`** so the income path does not publish hours-named events when income applies.
- **`IncomeComplianceDeterminationService#determine`** publishes only **`DeterminedIncomeMet`**, **`DeterminedIncomeInsufficient`**, or **`DeterminedIncomeActionRequired`**. Every payload includes generic **`hours_data`** (same shape as `HoursComplianceDeterminationService.aggregate_hours_for_certification`) for notifications and future combined CE messaging.
- **`CertificationBusinessProcess`** transitions the ex parte CE step on those three income events to the **same next steps** as the analogous hours events (`END_STEP` for met; `report_activities` for insufficient / action required).

## Possible follow-ups

- Member-facing copy that uses **`hours_data`** alongside income in `insufficient_income_email` (today templates remain income-focused; mailer receives `hours_data` when present).
- Product rules if both hours and income are partially satisfied (current path is hours-first, then income-only outcomes).
