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
"Layer 5: Model Customization" (in progress:
[#539](https://github.com/navapbc/oscer/issues/539)).

## Ownership

`.rb` files here are deployment-owned and untouched by `nava-platform app
update`. `README.md` and `.keep` are template-owned and refresh on update.
