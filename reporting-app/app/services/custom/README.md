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

Note: OSCER's services live flat under `app/services/` with no `Services::`
namespace, so the parent class is referenced as
`::ExemptionDeterminationService` (not `::Services::ExemptionDeterminationService`).
By contrast, `Rules::` and `Custom::` ARE proper namespaces. The full
namespacing guidance is in CUSTOMIZATION.md.

To wire a custom service into existing flows, see CUSTOMIZATION.md
(Extension points — Service and ruleset subclassing).

## Ownership

The `.rb` files you add here are deployment-owned. This `README.md` is
maintained upstream by OSCER; leave it unedited so syncing upstream changes
stays conflict-free.
