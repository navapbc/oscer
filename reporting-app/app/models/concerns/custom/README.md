# Deployment-Specific Model Concerns

Holds concerns that extend OSCER's base models with deployment-specific
validations, scopes, or methods. Namespaced under `Custom::`.

## Example

    # app/models/concerns/custom/certification_extensions.rb
    module Custom
      module CertificationExtensions
        extend ActiveSupport::Concern

        included do
          validates :county, presence: true
        end
      end
    end

Wire it into the base model with one `include` line:

    # app/models/certification.rb
    include Custom::CertificationExtensions

Concerns under `Custom::` are plain Ruby modules — they can also be included
in deployment-owned models, not only OSCER's base models.

For the full pattern, see CUSTOMIZATION.md (Extension points — Model extension).

## Ownership

The `.rb` files you add here are deployment-owned. This `README.md` is
maintained upstream by OSCER; leave it unedited so syncing upstream changes
stays conflict-free.
