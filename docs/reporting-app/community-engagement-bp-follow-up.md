# Community engagement (generic Strata events)

## In this PR

- **`CertificationBusinessProcess`** adds three transitions on generic CE events from `ex_parte_community_engagement_check`: **`DeterminedCommunityEngagementMet`**, **`DeterminedCommunityEngagementInsufficient`**, **`DeterminedCommunityEngagementActionRequired`** (same next steps as the analogous hours events where applicable).
- **`IncomeComplianceDeterminationService#determine`** publishes those event names (hours path unchanged; still **`DeterminedHours*`**).
- **`NotificationsEventListener`** subscribes and routes insufficient CE to **`insufficient_community_engagement_email`**, which can show **hours and/or income** shortfall using **`show_hours_insufficient`** / **`show_income_insufficient`** on the payload.

## Follow-up

- Wire the **hours** ex parte path to publish the same generic names when product is ready (and set show flags / payloads accordingly).
