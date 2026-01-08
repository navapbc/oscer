# Exemption Screener V2 - Architecture Documentation

## Overview

The Exemption Screener V2 transforms the exemption application entry point from a single static page to a multi-step questionnaire flow. Users answer one yes/no question per exemption type, with qualifying answers leading to an intermediate screen showing exemption details and documentation requirements before starting the application.

## Problem Statement

Members need to determine if they qualify for an exemption from activity reporting requirements. The current single-page screener with 2 exemption types is insufficient for the expanded 6 exemption types and doesn't provide adequate guidance on documentation requirements before starting an application.

## Solution Summary

A stateless, multi-step questionnaire implemented with standard Rails pages that:

- Presents one yes/no question per exemption type (6 total)
- Shows a "may qualify" intermediate screen with documentation requirements on "Yes" answers
- Supports back navigation via browser history
- Prevents duplicate applications via existing validation
- Uses configuration-driven exemption types for maintainability

```mermaid
flowchart LR
    subgraph screener [Exemption Screener Flow]
        Q1[Question 1] --> |No| Q2[Question 2]
        Q2 --> |No| Q3[Question 3]
        Q3 --> |No| Q4[Question 4]
        Q4 --> |No| Q5[Question 5]
        Q5 --> |No| Q6[Question 6]
        Q6 --> |No| Complete[No Exemptions]

        Q1 --> |Yes| MQ1[May Qualify]
        Q2 --> |Yes| MQ2[May Qualify]
        Q3 --> |Yes| MQ3[May Qualify]
        Q4 --> |Yes| MQ4[May Qualify]
        Q5 --> |Yes| MQ5[May Qualify]
        Q6 --> |Yes| MQ6[May Qualify]
    end

    MQ1 & MQ2 & MQ3 & MQ4 & MQ5 & MQ6 --> |Start Application| App[Exemption Application]
    Complete --> |Report Activities| AR[Activity Report]
```

## Key Design Principles

| Principle           | Application                                    |
| ------------------- | ---------------------------------------------- |
| **Simplicity**      | Standard Rails pages over Hotwire/SPA patterns |
| **Stateless**       | No session or database persistence of answers  |
| **Accessibility**   | WCAG 2.1 AA compliance, keyboard navigation    |
| **Configurability** | Initializer-based exemption type definitions   |
| **Maintainability** | I18n-ready text with config fallbacks          |

## Exemption Types

1. Medical Condition
2. Substance Use Treatment
3. Incarceration
4. Domestic Violence
5. Caregiver
6. Student

## Documentation Structure

| Document                                    | C4 Level | Purpose                                       |
| ------------------------------------------- | -------- | --------------------------------------------- |
| [Component Diagram](./c4-component.md)      | Level 3  | Internal component structure and interactions |
| [Architecture Decisions](./c4-decisions.md) | Level 4  | Key decisions with context and rationale      |

> **Note**: Context (Level 1) and Container (Level 2) diagrams are omitted as this feature operates entirely within the existing Rails monolith without external system integrations.

## Quick Reference

### User Flow

```mermaid
flowchart TD
    Dashboard[Member Dashboard] --> Start[Start Screener]
    Start --> Q{Question N}

    Q --> |Yes| MayQualify[May Qualify Screen]
    Q --> |No| NextQ{More Questions?}

    NextQ --> |Yes| Q
    NextQ --> |No| Complete[Complete Screen]

    MayQualify --> |Start Application| Create[Create ExemptionApplicationForm]
    MayQualify --> |Go Back| Q

    Create --> Upload[Document Upload Page]
    Complete --> |Report Activities| ActivityReport[Activity Report Flow]
    Complete --> |Return| Dashboard
```

### Component Interaction

```mermaid
flowchart LR
    Controller[ExemptionScreenerController] --> Config[ExemptionTypeConfig]
    Controller --> Model[ExemptionApplicationForm]
    Config --> Initializer[exemption_types.rb]
    Config --> I18n[Locale Files]
    Model --> |Creates| App[Application Record]
```

## Technical Constraints

- **Unique Application**: Only one exemption application per certification case (enforced by existing model validation)
- **Authentication**: Requires authenticated member session
- **Certification Context**: Must have an active certification case
- **USWDS Styling**: Must use existing design system components

## Related Documentation

- [Batch Upload Architecture](../batch-upload/README.md) - Example of full C4 documentation for system integrations
- [C4 Architecture Documentation Guide](../../prs/C4-ARCHITECTURE-DOCUMENTATION.md) - PR template explaining C4 adoption

---

## Changelog

| Date       | Author       | Change                           |
| ---------- | ------------ | -------------------------------- |
| 2025-01-08 | Architecture | Initial C4 documentation created |
