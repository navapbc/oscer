# Adopt Attribute-Based Access Control (ABAC) Over Internal Role Management

- Status: Accepted
- Deciders: Bao Nguyen, Loren Yu, Sumi Thaiveettil, Mike Giver, Cael Crawford
- Date: 2025-12-11 

Technical Story: https://github.com/navapbc/oscer/issues/37

## Context and Problem Statement

OSCER requires an authorization system to control staff access based on roles, program affiliation, and regional assignment. The platform will integrate with external Single Sign-On (SSO) providers (e.g., Active Directory) that already serve as the authoritative source for user attributes. Should OSCER build and maintain its own internal role management system, or leverage the attributes already provided by external identity providers?

## Decision Drivers <!-- optional -->

- External SSO providers (Active Directory) already maintain authoritative user attributes including roles, program affiliation, and regional assignment
- Minimizing database complexity and avoiding redundant data storage
- Reducing ongoing maintenance burden for role management
- Avoiding the need to build administrative UI for role assignment
- Future reusability of the authorization pattern in the Strata SDK
- Supporting common policy patterns (default caseworker/admin, program-segmented, region-segmented)

## Considered Options

- ** Option 1:** Attribute-Based Access Control (ABAC) using external SSO attributes
- **Option 2:** Internal RBAC with dedicated roles and groups tables in OSCER database
- **Option 3:** Configuration-based permissioning with a permissions table (rather than code-based Pundit policies)

## Decision Outcome

**Chosen option 1: **"Attribute-Based Access Control (ABAC) using external SSO attributes", because it leverages the existing authoritative source of truth for user attributes, eliminates redundant role storage, requires no new database tables or admin UI, and provides a clean abstraction pattern for the Strata SDK.
Positive Consequences

- No new database tables required for role management
- No administrative UI needed in OSCER for role assignment—all changes happen in the state's AD
- Simplified security architecture with reduced internal maintenance
- Caseworker attributes (program, region, role) flow directly from SSO during authentication
- Authorization logic stays in code (Pundit policies) where it can be version-controlled and tested
- Creates a reusable pattern for Strata SDK with out-of-the-box policy templates
- Supports flexible mapping from external SSO roles to internal standardized policies

**Negative Consequences**

- Dependent on external SSO providers delivering consistent, well-structured attributes
- Minor schema migration required on Users table to persist essential attributes
- Policy logic must be updated in code rather than configured in a database
  
## Pros and Cons of the Options

### Option 1: ABAC Using External SSO Attributes

* Good, because it uses AD as the single source of truth—no data duplication
* Good, because it requires no new database tables for role management
* Good, because it eliminates the need for an admin UI to manage roles
* Good, because it reduces long-term maintenance overhead
* Good, because it creates a reusable pattern for Strata SDK
* Bad, because it depends on external SSO providing well-structured attributes

### Option 2: Internal RBAC with Roles and Groups Tables

* Good, because it provides full control over role definitions within OSCER
* Good, because it doesn't depend on external attribute structure
* Bad, because it requires dedicated roles and groups tables in the database
* Bad, because it necessitates building an admin UI for role assignment
* Bad, because it creates redundant storage of information already in AD
* Bad, because it increases ongoing maintenance burden

### Option 3: Configuration-Based Permissioning Table

* Good, because permissions could be modified without code changes
* Good, because it provides visibility into permissions via database
* Bad, because it separates authorization logic from the code that enforces it
* Bad, because it still requires internal role management infrastructure
* Bad, because it adds complexity without leveraging existing SSO attributes

## Implementation Strategy

1. **Environment Setup:** Create demo environment with mock caseworker accounts configured with varied attributes (region, roles)
2. **Policy Updates:** Update Pundit policies across controllers to evaluate user attributes dynamically
3. **User Data Migration:** Minor schema migration on Users table to persist essential SSO attributes
4. **Demo Execution:** Demonstrate granular access controls by logging in as different attribute-defined users

## Future: Strata SDK Integration

The ABAC implementation enables a configuration layer for the Strata SDK that maps external SSO roles to standardized internal policies:

| External SSO Role (Example) | Internal Strata Policy | Description |
|----------------------------|------------------------|-------------|
| admin1, TeamLead_A | strataAdmin | Supervisory actions (e.g., case reassignment) |
| casework, frontline_user | strataCaseWorker | Standard caseworker access (e.g., case viewing, task completion) |
