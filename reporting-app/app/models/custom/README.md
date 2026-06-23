# Deployment-Specific Models

Holds models unique to this deployment. Place new ActiveRecord models here,
namespaced under `Custom::`.

## Example

    # app/models/custom/disaster_declaration.rb
    module Custom
      class DisasterDeclaration < ApplicationRecord
        # deployment-specific fields and behavior
      end
    end

Ship a corresponding migration. Models exposed to controllers also need a
Pundit policy (`make new-authz-policy MODEL=...`) — `ApplicationController`
raises if `authorize`/`policy_scope` are skipped.

To wire a custom model into existing flows, see CUSTOMIZATION.md
(Extension points — Model extension).

## Ownership

The `.rb` files you add here are deployment-owned. This `README.md` is
maintained upstream by OSCER; leave it unedited so syncing upstream changes
stays conflict-free.
