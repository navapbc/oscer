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

## Federal-floor invariants

Composition overrides may **add** exemption paths or **tighten** eligibility
beyond OSCER's defaults, but must not relax federally-required rules. The
base rulesets encode the federal floor.

To wire a custom ruleset into evaluation, see CUSTOMIZATION.md
"Layer 4: Service and Ruleset Customization".

## Ownership

`.rb` files here are deployment-owned and untouched by `nava-platform app
update`. `README.md` and `.keep` are template-owned and refresh on update.
