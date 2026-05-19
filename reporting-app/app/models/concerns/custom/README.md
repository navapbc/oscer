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

For the full pattern, see CUSTOMIZATION.md "Layer 5: Model Customization"
(in progress: [#539](https://github.com/navapbc/oscer/issues/539)).

## Ownership

`.rb` files here are deployment-owned and untouched by `nava-platform app
update`. `README.md` and `.keep` are template-owned and refresh on update.
