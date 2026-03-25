# Authentication

**Triple auth system:**
- **Members (form)**: Devise + Auth adapter (Cognito in prod, Mock in dev/test)
- **Members (OIDC)**: `Auth::MemberOidcController` → `MemberOidcProvisioner` (SSO for members)
- **Staff**: OmniAuth OIDC SSO → `StaffUserProvisioner` → role mapping via `config/sso_role_mapping.yml`
- **API**: HMAC authentication via `ApiHmacAuthentication` concern

**Mock adapter triggers** (dev/test with `AUTH_ADAPTER=mock`):

| Scenario | Trigger |
|----------|---------|
| Unconfirmed account | Email contains `unconfirmed` |
| Invalid credentials | Password is `wrong` |
| MFA challenge | Email contains `mfa` |
| Successful login | Any other email/password |
