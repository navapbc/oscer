# Deployment-Specific Services

Holds services unique to this deployment. Place subclasses of base services
here, namespaced under `Custom::`.

## Example

    # app/services/custom/exemption_determination_service.rb
    module Custom
      class ExemptionDeterminationService < ::ExemptionDeterminationService
        # deployment-specific overrides
      end
    end

To wire a custom service into existing flows, see CUSTOMIZATION.md
"Layer 4: Service and Ruleset Customization" (in progress:
[#539](https://github.com/navapbc/oscer/issues/539)).

## Ownership

`.rb` files here are deployment-owned and untouched by `nava-platform app
update`. `README.md` and `.keep` are template-owned and refresh on update.
