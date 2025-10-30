# Authentication & Authorization

## Authentication

Authentication is the process of verifying the credentials of a user. We use AWS Cognito for authentication.

- User credentials are stored in AWS Cognito
- Password policy is enforced by Cognito
- Custom pages are built for the AWS Cognito flows (login, signup, forgot password, etc.). We aren't using the hosted UI that Cognito provides since we need more control over the UI and content.
- [Devise](https://www.rubydoc.info/github/heartcombo/devise/main) and [Warden](https://github.com/wardencommunity/warden/wiki) facilitate auth and session management

## Authorization

Authorization is the process of determining whether a user has access to a specific resource. We use [Pundit](https://github.com/varvet/pundit) for authorization.

- Policies (`app/policies`) are created for each model to define who can perform what actions
- Policies are used in controllers to authorize actions
- Policies are used in views to show/hide elements based on user permissions

### Generating policies

```sh
make new-authz-policy MODEL=Foo
```

### Testing policies

[`pundit-matchers`](https://github.com/pundit-community/pundit-matchers) provides RSpec matchers for testing Pundit policies. Refer to existing policy spec files, or the spec file generated when creating a new policy, for examples.

### Verifications

We use a few `after_action` Pundit callbacks in the application controller to verify that our controllers are authorizing resources correctly. These aren't foolproof, but they can help catch some common mistakes:

- If you forget to call `authorize` in a controller action, you'll see an exception like `AuthorizationNotPerformedError`.
- If you forget to call `policy_scope` in a controller action, you'll see an exception like `PolicyScopingNotPerformedError`.

To opt out of these checks on actions that don't need them, you can add `skip_after_action :verify_authorized` or `skip_after_action :verify_policy_scoped` to your controller. Alternatively, you can add `skip_authorization` or `skip_policy_scope` to your controller action.

### Mock Auth Adapter Behavior (Development & Test)

When running in test environments (or `dev` with `AUTH_ADAPTER=mock`), the application uses a mock authentication adapter to simulate interactions with an external auth provider. This allows you to test various authentication flows and error states without needing real external infrastructure.

#### How to Trigger Different Auth Scenarios
The mock adapter looks for specific keywords in the email or password fields during login to simulate different outcomes:

| Scenario | How to Trigger | Result |
| -------- | -------------- | ------ |
| Unconfirmed account |	Use an email containing the word unconfirmed | Raises Auth::Errors::UserNotConfirmed |
| Invalid credentials |	Use the password wrong	                     | Raises Auth::Errors::InvalidCredentials
| MFA challenge       |	Use an email containing the word mfa	     | Returns a response with challenge_name: SOFTWARE_TOKEN_MFA
| Successful login    |	Use any other email and password combination | Returns a mock token and UID
