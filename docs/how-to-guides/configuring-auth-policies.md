# Configuring Authorization Policies

This guide explains how to configure authorization policies in the application using Attribute-Based Access Control (ABAC). We use the [Pundit](https://github.com/varvet/pundit) gem to manage our authorization logic.

## Attribute-Based Access Control (ABAC)

ABAC is an authorization model that provides access rights to users based on attributes (characteristics) of the user, the resource, and the environment. In this application, we primarily use user attributes like `role` and `region` to determine access.

### User Attributes

The `User` model (`app/models/user.rb`) defines several attributes and helper methods used for authorization:

- **`role`**: Defines the user's primary responsibility (e.g., `admin`, `caseworker`).
- **`region`**: Defines the geographical area the user is assigned to.

#### Helper Methods

The `User` model provides convenient methods to check these attributes:

```ruby
def admin?
  role == "admin"
end

def caseworker?
  role == "caseworker"
end

def staff?
  admin? || caseworker?
end
```

### Policy Configuration

Policies are located in `app/policies/` and inherit from `ApplicationPolicy`. They define authorization logic for specific controllers or resources.

#### Example: `StaffPolicy`

The `StaffPolicy` (`app/policies/staff_policy.rb`) is a general-purpose policy used to restrict access to controllers that should only be accessible by staff members (admins and caseworkers).

```ruby
class StaffPolicy < ApplicationPolicy
  def index?
    staff?
  end

  def show?
    staff?
  end

  # ... other actions ...

  private

  def staff_in_region?
    staff? && in_region?
  end

  delegate :admin?, to: :user
  delegate :staff?, to: :user
end
```

### Configuring Access in Controllers

To enforce a policy in a controller, use the `authorize` method provided by Pundit.

```ruby
class Staff::BaseController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_authorized

  def index
    authorize :staff, :index?
    # ...
  end
end
```

In this example, `authorize :staff, :index?` tells Pundit to use `StaffPolicy#index?` to authorize the action.

### Scoping Data Based on Attributes

ABAC is also used to restrict the data a user can see. This is handled by the `Scope` class within a policy.

#### Example: Regional Data Restriction

In `StaffPolicy`, the `Scope` class can be configured to restrict data based on the user's region:

```ruby
class StaffPolicy < ApplicationPolicy
  # ...
  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.admin?
        scope.all
      elsif user.staff?
        # Restrict to records in the user's region
        scope.where(region: user.region)
      else
        scope.none
      end
    end
  end
end
```

By using `policy_scope(Model)` in your controller, you ensure that users only see data they are authorized to access based on their attributes.

## Best Practices

1.  **Keep Policies Simple**: Policies should only contain authorization logic. Complex business logic belongs in models or services.
2.  **Use Helper Methods**: Define helper methods in the `User` model for common attribute checks to keep policies readable.
3.  **Always Verify Authorization**: Use `after_action :verify_authorized` and `after_action :verify_policy_scoped` in your base controllers to ensure authorization is never skipped.
4.  **Leverage Scopes**: Always use `policy_scope` when fetching collections of records to ensure data-level security.
