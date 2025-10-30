# Application Security

Application security is a top priority for technology application development, which is why the Rails framework's security helper methods and countermeasures help speed up secure application delivery. However, the framework isn't useful by itself; its helper methods and configurations only work if they are used properly.

Each item below will be checked if it is already implemented by default, or unchecked if it is not implemented by default. This is meant to be a living document and should be updated as additional security tools and configurations are implemented, as well as when new vulnerabilities are discovered or introduced.

This document uses the Rails Guide to [Securing Rails Applications](https://guides.rubyonrails.org/security.html) to audit this project's Rails security best practices.

## Sessions
We use Devise to manage sessions and cookies. Devise configuration is managed in the `devise.rb` (`/<APP_NAME>/config/initializers/devise.rb`) file. For more detailed information, see the [Devise documentation](https://rubydoc.info/github/heartcombo/devise).
- [x] SSL (`config.force_ssl = true`) is enforced in production environments.
- [x] Provide the user with a prominent logout button to make it easy to clear the session on public computers.
- [x] Cookies stored client side do not contain sensitive information.
- [x] Cookies time out in 15 minutes of inactivity
    - Note: That is set with `config.timeout_in` in the Devise configuration file (`/<APP_NAME>/config/initializers/devise.rb`).
- [x] Cookies are encrypted client side.
    - Note: Devise uses BCrypt and the secret_key_base by default for secret hashing.
- [ ] Expire sessions after a set amount of time, regardless of activity,
    - Note: Automated session expiration can be easily set by the auth service, such as in AWS Cognito.
- [ ] Use a nonce generator to protect against cookie replay attacks.
    - Note: The commented out code for this is located in `/<APP_NAME>/config/initializers/content_security_policy.rb` Review the impact this may have if there are several application servers.
- [x] Automatically expire sessions on sign in and sign out.
    - Note. This is set in the Devise configuration file (`/<APP_NAME>/config/initializers/devise.rb`) with `config.expire_all_remember_me_on_sign_out = true`.

## Cross-Site Request Forgery (CSRF)
- [x] GET, POST, DELETE, and rails’ resources are used appropriately in the `routes.rb` file.
- [x] Pass a CSRF token to the client.
    - Note: This is accomplished with `<%= csrf_meta_tags %>` in `/<APP_NAME>/app/views/layouts/application.html.erb`
- [ ] Set forgery protection in production

## Redirection and Files
There is currently no file upload or download functionality at this time, so please review these items when adding file management functionality.
- [x] Do not use user inputs to generate routes (ie. creating a route with the username), which is vulnerable to XSS attacks.
    - [x] `link_to` methods do not interpolate to user inputs.
    - [x] `redirect_to` methods do not interpolate to user inputs.
- [ ] Prevent files from being uploaded if the filename do not match a set of permitted characters.
    - Note: Filtering on filename on its own can still leave an application vulnerable to XSS attacks.
- [ ] Do not allow file uploads to place files in the public directory as code in those files may be executed by the browser.
- [ ] Prevent users from downloading files to which they shouldn't have access.
    - [ ] Prevent files from being downloaded if the filename do not match a set of permitted characters.
    - [ ] For website search, prevent including files in the search results if the file is not from an appropriate directory.

## User Management
- [x] Store only cryptographically hashed passwords, not plain-text passwords.
- [x] Consider Rails' built-in `has_secure_password` method which supports secure password hashing, confirmation, and recovery mechanisms.
    - Note: When using Devise there's no need to use `has_secure_password`.
- [x] Username error is generic and does not indicate whether it was an error with the username or password.
- [x] Forgot password confirms the email was sent, and not whether the username exists.
- [x] Use a secondary verification when users change their password
    - Note: Change password requires 6 digit code from email sent to user's email address.
- [ ] Require user's password when changing email.
- [x] Include honeypot fields and logic on Non logged in forms to catch bots that spam all fields (good resource: https://nedbatchelder.com/text/stopbots.html).
- [ ] Consider using Captcha on account creation, login, change password, and change email forms.
    - Note: Captchas are often not accessible to screen readers and their use should be part of a UX discussion.
- [x] Filter log entries so they do not include passwords or secrets
    - Note:  Log filtering is set in `/<APP_NAME>/config/initializers/filter_parameter_logging.rb`: `:passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn`.
- [x] Use the correct Ruby REGEX: `\A` and `\z` and not the more common: `/^` and `$/`.
    - Note: If there is a need to use `/^` and `$/` in the regex, add `multiline: true` to regex `format:` in validations.
- [x] When searching for data belonging to the user, search using Active Record from the user and not from the target data object. ie. Instead of doing: `@task = Task.find(params[:id])`, instead do: `@user.tasks.find(params[:id])`.
    - Note: This application is also using [pundit](https://github.com/varvet/pundit) to support resource authorization.

## Injection
- [ ] When defining security related `before_action` and `after_action` on controllers, use `except: […]` instead of `only:[…]` Ie. Instead of `after_action :verify_policy_scoped, only: :index` use `after_action :verify_policy_scoped, except:[ :rails_health_check, :users, :dev, ...]`. This ensures that when new views are added, they're behind the security actions by default.
- [x] Don't interpolate params into SQL fragments. Ie. `.where(“name ='#{params[:name]}'”`.
- [x] Ensures all cookies are `httponly`.
    - Note: While we’re not setting `secure: true` on the cookies themselves, the `config.force_ssl = true` option in production sets them as `httponly`.
- [x] Sanitize content in the erb files that come from user inputs, using `<%=h <some user provided input> =>` to protect against defacement.
- [x] Use a permitted list of tags in inputs that allow html or when allowing a text input that will be converted into html, using:
    - Note: The most common Rails tool for text to html conversion is RedCloth.
    ```
    tags = %w(a acronym b strong i em li ul ol h1 h2 h3 h4 h5 h6 blockquote br cite sub sup ins p)
    s = sanitize(user_input, tags: tags, attributes: %w(href title))
    ```
- [x] Rails `sanitize()` method is used on inputs that will be presented to the UI, including the Admin UI if there is one.
    - Note: While consensus seems mixed about the necessity to sanitize Rails input fields for defacement, sanitizing inputs is very useful to protect against encoding injection.
- [ ] Inputs for custom colors or CSS filters are sanitized with Rail's `sanitize()` method, and the application builds the CSS in the web application first and ensures it is valid CSS before sanitizing.
    - Note: We don't include that functionality, but this is a common attack vector in applications that do.
- [x] Controllers that output strings, rather than views, are escaped.
- [x] All methods called by the application to execute commands on the underlying operating system include the `parameters` parameter, ie. `system(command, parameters)`. Applicable methods include:
    * `system()`
    * `exec()`
    * `spawn()`
    * `command`
- [x] Don't use the `open()` method to access files, instead use `File.open()` or `IO.open()` that will not execute commands.
- [ ] [`ActionDispatch::HostAuthorization`](https://guides.rubyonrails.org/configuring.html#actiondispatch-hostauthorization) is configured in production to prevent DNS rebinding attacks.

## Unsafe Query Generation
- [x] Confirm `deep_munge` hasn't been disabled.
    - Note: `config.action_dispatch.perform_deep_munge` is `true` by default.

## HTTP Security Headers
Default security headers can be overridden in `application.rb` (`/<APP_NAME>/config/application.rb`) with `config.action_dispatch.default_headers`.
- [x] Lock down X-Frame-Options to be as restrictive as possible.
    - Note: By default this is set to allow iframes from the same origin.
    - Note: Set this to deny if not using any iframes to embed.
    - Note: If you need to permit an iframe from another origin, a controller can then use an `after_action :allow_some_service`.
- [ ] To help protect against XSS and injection attacks, define a Content-Security-Policy in the provided `/<APP_NAME>/config/initializers/content_security_policy.rb`.
    - Note: Set the policy to be more restrictive than you need and you can override defaults when necessary in the controllers.
- [ ] Log content security policy violations to continuously improve security by setting the report_uri config on the content security policy and configure a controller to log the reports.
    - Note: `report_uri` is being deprecated, and will eventually become `report_to`.
- [x] Set `csp_meta_tag` in `/<APP_NAME>/config/application.rb`.
- [ ] Use the `csp_meta_tag` tag with nonce generation in the content security policy.
- [ ] Configure which browser features are allowed in `/<APP_NAME>/config/initializers/permissions_policy.rb`.
    - Note: This policy can be more restrictive than necessary because features can be allowed on specific controllers.
- [ ] If opening up endpoints as APIs, configure CORS, by installing and configuring the `rack-cors` gem.

## Intranet and Admin Security
If adding an Admin view, consider adding the following:
- [ ] Sanitize all user inputs as they may be viewed here even if they aren't visible anywhere else in the application.
Some effective admin protection strategies include:
    - [ ] Limit admin role privileges using the principle of least privilege
    - [ ] Geofence admin login IP to the USA.
    - [ ] Consider putting the admin app at a subdomain so the cookie for application can't be used for the admin console and vice-versa.

## Environmental Security
- [x] Secrets are not stored in the application repository.

## Dependency Management and CVEs'
- [x] Use a service to be notified when libraries are outdated
    - Note: We're using dependabot to notify us if we have outdated gems.

## Additional Reading
* [Securing Rails Applications](https://guides.rubyonrails.org/security.html)
