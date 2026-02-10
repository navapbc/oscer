# Setting Up Keycloak for Local SSO Development

This guide walks through setting up Keycloak as a local identity provider (IdP) to test Staff SSO authentication. Keycloak will issue OIDC tokens that OSCER validates to authenticate staff users.

## Prerequisites

- Docker installed and running
- OSCER reporting-app running locally (via Docker Compose)

## 1. Start Keycloak

Pull and run Keycloak in development mode:

```bash
docker run -d \
  --name keycloak \
  -p 8080:8080 \
  -e KC_BOOTSTRAP_ADMIN_USERNAME=admin \
  -e KC_BOOTSTRAP_ADMIN_PASSWORD=admin \
  quay.io/keycloak/keycloak:latest \
  start-dev
```

Access the admin console at http://localhost:8080/admin (login: admin/admin).

## 2. Create the OSCER Realm

1. Click the **master** dropdown (top-left) → **Create realm**
2. Realm name: `oscer`
3. Click **Create**

## 3. Create the Client

1. Go to **Clients** → **Create client**
2. **General Settings:**
   - Client ID: `oscer-staff`
   - Click **Next**
3. **Capability config:**
   - Client authentication: **ON**
   - Click **Next**
4. **Login settings:**
   - Valid redirect URIs: `http://localhost:3000/*`
   - Click **Save**
5. Go to **Credentials** tab → copy the **Client secret**

## 4. Add Groups Scope (for role mapping)

### Create the scope

1. Go to **Client scopes** → **Create client scope**
2. Name: `groups`
3. Type: `Default`
4. Click **Save**

### Add the mapper

1. In the `groups` scope, go to **Mappers** tab
2. Click **Add mapper** → **By configuration** → **Group Membership**
3. Configure:
   - Name: `groups`
   - Token Claim Name: `groups`
   - Full group path: **OFF**
4. Click **Save**

### Assign to client

1. Go to **Clients** → `oscer-staff` → **Client scopes** tab
2. Click **Add client scope**
3. Select `groups` → **Add** → **Default**

## 5. Create Groups

1. Go to **Groups** → **Create group**
2. Create these groups (names must match `config/sso_role_mapping.yml`):
   - `OSCER-Admin`
   - `OSCER-Caseworker`

## 6. Create a Test User

1. Go to **Users** → **Add user**
2. Fill in:
   - Username: `testuser`
   - Email: `test@example.gov`
   - First name: `Test`
   - Last name: `User`
3. Click **Create**
4. Go to **Credentials** tab → **Set password**
   - Password: `password`
   - Temporary: **OFF**
5. Go to **Groups** tab → **Join Group** → select `OSCER-Caseworker`

## 7. Configure OSCER

Add to your `.env` file:

```bash
# Staff SSO
SSO_ENABLED=true
SSO_ISSUER_URL=http://localhost:8080/realms/oscer
SSO_CLIENT_ID=oscer-staff
SSO_CLIENT_SECRET=<paste-secret-from-step-3>
SSO_REDIRECT_URI=http://localhost:3000/auth/sso/callback
SSO_SCOPES=openid profile email groups
```

### Running OSCER in Docker

When OSCER runs inside Docker, it cannot reach `localhost:8080` (that refers to the container itself). Add this extra variable:

```bash
SSO_DISCOVERY_URL=http://host.docker.internal:8080/realms/oscer
```

This tells OSCER to fetch OIDC configuration via the Docker host network, while `SSO_ISSUER_URL` remains `localhost` for browser redirects and token validation.

## 8. Test the Login

1. Restart OSCER: `docker compose restart web` (or restart your Rails server)
2. Go to http://localhost:3000/users/sign_in
3. Click **Sign in with State Account**
4. Login with `testuser` / `password`
5. You should be redirected back and logged in as a caseworker

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `Connection refused` | Keycloak not running or wrong URL | Check `docker ps` and verify port 8080 |
| `404` on discovery | Realm doesn't exist | Create the `oscer` realm |
| `Invalid scopes` | Missing `groups` scope | Complete step 4 or remove `groups` from `SSO_SCOPES` |
| `Invalid issuer` | URL mismatch | Ensure `SSO_ISSUER_URL` matches token's issuer exactly |
| `Access denied` | User not in a mapped group | Add user to `OSCER-Admin` or `OSCER-Caseworker` group |

## Stopping Keycloak

```bash
docker stop keycloak
docker rm keycloak
```

To persist data between restarts, add a volume:

```bash
docker run -d \
  --name keycloak \
  -p 8080:8080 \
  -v keycloak_data:/opt/keycloak/data \
  -e KC_BOOTSTRAP_ADMIN_USERNAME=admin \
  -e KC_BOOTSTRAP_ADMIN_PASSWORD=admin \
  quay.io/keycloak/keycloak:latest \
  start-dev
```
