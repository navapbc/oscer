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

Ship a corresponding migration. To wire a custom model into existing flows,
see CUSTOMIZATION.md "Layer 5: Model Customization".

## Ownership

`.rb` files here are deployment-owned and untouched by `nava-platform app
update`. `README.md` and `.keep` are template-owned and refresh on update.
