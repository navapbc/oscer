// Specify assets to be included in the final application.
// Any assets linked here will be compiled by Sprockets into
// the public/assets folder when running assets:precompile.

//= link_tree ../images
//= link_tree ../../javascript .js
//= link_tree ../../../vendor/javascript .js

// USWDS assets
// You can reference these relative to the dist directory (e.g. "assets/img" and "assets/js")
//= link_tree ../../../node_modules/@uswds/uswds/dist/img
//= link_tree ../../../node_modules/@uswds/uswds/dist/fonts
//= link @uswds/uswds/dist/js/uswds-init.min.js
//= link @uswds/uswds/dist/js/uswds.min.js

// Compiled CSS and JS
//= link_tree ../builds
//= link application.css
