# Deployment-Specific Rulesets

Holds rulesets unique to this deployment. Place subclasses of base rulesets
here, namespaced under `Rules::Custom::`.

## Example

    # app/models/rules/custom/exemption_ruleset.rb
    module Rules
      module Custom
        class ExemptionRuleset < Rules::ExemptionRuleset
          # deployment-specific rule methods + composition override
        end
      end
    end

## Federally-required exemptions

Deployments may grant additional exemptions but must not narrow or remove
the exemptions federal Medicaid law requires (disability, pregnancy, Native
American / Alaska Native, age). The base rulesets encode that minimum.

To wire a custom ruleset into evaluation, see CUSTOMIZATION.md
"Layer 4: Service and Ruleset Customization" (in progress:
[#539](https://github.com/navapbc/oscer/issues/539)).

## Ownership

`.rb` files here are deployment-owned and untouched by `nava-platform app
update`. `README.md` is template-owned and refreshes on update.
