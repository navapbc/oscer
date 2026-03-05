//= require activestorage
// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import { Turbo } from "@hotwired/turbo-rails"
import "controllers"

// Disable Turbo Drive globally — standard link clicks use full browser navigation.
// Turbo Frames still work independently for partial-page updates (e.g., auto-refresh).
// Links inside frames use data-turbo-frame="_top" for full navigation, and download
// links use data-turbo="false" to bypass Turbo's fetch interceptor.
Turbo.session.drive = false
