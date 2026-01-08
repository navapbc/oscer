# Exemption Screener V2 - Component Diagram

> **C4 Level 3**: Components within the Rails Application

## Overview

This document describes the internal component structure of the Exemption Screener V2 feature. All components reside within the existing Rails monolith.

## Component Architecture

```mermaid
flowchart TB
    subgraph views [Views Layer]
        Show[show.html.erb]
        MayQualify[may_qualify.html.erb]
        Complete[complete.html.erb]
    end

    subgraph controller [Controller Layer]
        ESC[ExemptionScreenerController]
    end

    subgraph config [Configuration Layer]
        ETC[ExemptionTypeConfig]
        Init[exemption_types.rb initializer]
        Locale[en.yml locale files]
    end

    subgraph models [Model Layer]
        EAF[ExemptionApplicationForm]
        CC[CertificationCase]
    end

    subgraph existing [Existing Components]
        Auth[Authentication]
        CertService[CertificationService]
    end

    ESC --> Show
    ESC --> MayQualify
    ESC --> Complete

    ESC --> ETC
    ESC --> EAF
    ESC --> CertService

    ETC --> Init
    ETC --> Locale

    EAF --> CC
    CertService --> CC

    Auth --> ESC
```

## Component Descriptions

### Controller Layer

#### ExemptionScreenerController

**Responsibility**: Orchestrates the multi-step questionnaire flow

**Actions**:

| Action | Purpose |
| ------ | ------- |
| `show` | Display a single yes/no question |
| `answer` | Process answer, redirect to may_qualify or next question |
| `may_qualify` | Show exemption details and documentation requirements |
| `create_application` | Create ExemptionApplicationForm, redirect to documents |
| `complete` | Show "no exemptions" screen when all answers are "No" |

**Dependencies**:

- `ExemptionTypeConfig` - Retrieves exemption type configuration
- `CertificationService` - Loads certification context
- `ExemptionApplicationForm` - Creates application records

### Configuration Layer

#### ExemptionTypeConfig

**Responsibility**: Provide access to exemption type definitions with I18n support

**Interface**:

```ruby
ExemptionTypeConfig.all           # All exemption types
ExemptionTypeConfig.ordered       # Types sorted by display order
ExemptionTypeConfig.find(:type)   # Single type configuration
ExemptionTypeConfig.enum_hash     # Hash for Rails enum definition
ExemptionTypeConfig.valid_values  # Array of valid type strings
ExemptionTypeConfig.question_for(:type)  # I18n-aware question text
```

**Data Flow**:

```mermaid
flowchart LR
    Init[Initializer] --> |Ruby Hash| Config[ExemptionTypeConfig]
    I18n[Locale Files] --> |Optional Override| Config
    Config --> |Formatted Data| Controller
    Config --> |Enum Hash| Model
```

#### exemption_types.rb Initializer

**Responsibility**: Define exemption types, order, and default text

**Structure**:

```ruby
Rails.application.config.exemption_types = {
  type_key: {
    question: "Question text",
    explanation: "Detailed explanation",
    yes_answer: "Affirmative statement",
    documentation: ["Required doc 1", "Required doc 2"],
    order: 1,
    enabled: true
  }
}
```

### Model Layer

#### ExemptionApplicationForm

**Responsibility**: Persist exemption application data

**Key Attributes**:

- `exemption_type` - Enum from ExemptionTypeConfig
- `certification_case_id` - Association to certification case

**Validations**:

- Unique per certification case (prevents duplicates)
- Valid exemption type from configuration

### Views Layer

| View | Purpose |
| ---- | ------- |
| `show.html.erb` | Single question with Yes/No radio buttons |
| `may_qualify.html.erb` | Exemption details, documentation list, Start/Back buttons |
| `complete.html.erb` | No exemptions message, links to activity report or dashboard |

## Data Flow

### Question Navigation Flow

```mermaid
sequenceDiagram
    participant U as User
    participant C as Controller
    participant Config as ExemptionTypeConfig
    participant V as View

    U->>C: GET /exemption-screener/question/:type
    C->>Config: find(type)
    Config-->>C: {question, explanation, order}
    C->>Config: ordered (for navigation)
    Config-->>C: [type1, type2, ...]
    C->>V: render show
    V-->>U: Question page

    U->>C: POST /exemption-screener/question/:type (answer=yes)
    C->>V: redirect to may_qualify
    V-->>U: May qualify page

    U->>C: POST /exemption-screener/question/:type (answer=no)
    C->>Config: next_type(current_type)
    Config-->>C: next_type or nil
    C->>V: redirect to next question or complete
```

### Application Creation Flow

```mermaid
sequenceDiagram
    participant U as User
    participant C as Controller
    participant EAF as ExemptionApplicationForm
    participant CC as CertificationCase

    U->>C: POST /exemption-screener/may-qualify/:type
    C->>CC: find certification_case
    CC-->>C: case record
    C->>EAF: create(exemption_type, certification_case_id)
    EAF->>EAF: validate uniqueness
    EAF-->>C: created record
    C-->>U: redirect to document upload
```

## Navigation State Machine

```mermaid
stateDiagram-v2
    [*] --> Question1: Start Screener
    
    Question1 --> MayQualify1: Yes
    Question1 --> Question2: No
    
    Question2 --> MayQualify2: Yes
    Question2 --> Question3: No
    
    Question3 --> MayQualify3: Yes
    Question3 --> Question4: No
    
    Question4 --> MayQualify4: Yes
    Question4 --> Question5: No
    
    Question5 --> MayQualify5: Yes
    Question5 --> Question6: No
    
    Question6 --> MayQualify6: Yes
    Question6 --> Complete: No
    
    MayQualify1 --> Application: Start
    MayQualify2 --> Application: Start
    MayQualify3 --> Application: Start
    MayQualify4 --> Application: Start
    MayQualify5 --> Application: Start
    MayQualify6 --> Application: Start
    
    MayQualify1 --> Question1: Back
    MayQualify2 --> Question2: Back
    MayQualify3 --> Question3: Back
    MayQualify4 --> Question4: Back
    MayQualify5 --> Question5: Back
    MayQualify6 --> Question6: Back
    
    Application --> [*]: Documents Flow
    Complete --> [*]: Dashboard/Activity Report
```

## Error Handling

| Scenario | Handling |
| -------- | -------- |
| Invalid exemption type in URL | Redirect to first question |
| Existing application | Redirect to existing application |
| No certification case | Redirect to dashboard with error |
| Application creation failure | Re-render may_qualify with errors |

## Security Considerations

- **Authentication**: All actions require authenticated user
- **Authorization**: User must own the certification case
- **CSRF Protection**: Standard Rails form tokens
- **Input Validation**: Exemption type validated against configuration

