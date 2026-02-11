# Setting Up Keycloak for Local SSO Development

This guide walks through setting up Keycloak as a local identity provider (IdP) to test Staff SSO authentication. Keycloak will issue OIDC tokens that OSCER validates to authenticate staff users.

## Prerequisites

- Docker and Docker Compose installed
- OSCER reporting-app running locally (via Docker Compose)

## 1. Add Keycloak to Docker Compose

Add Keycloak to your `docker-compose.yml` (or `docker-compose.override.yml`):

```yaml
services:
  keycloak:
    image: quay.io/keycloak/keycloak:latest
    command: start-dev
    environment:
      KC_BOOTSTRAP_ADMIN_USERNAME: admin
      KC_BOOTSTRAP_ADMIN_PASSWORD: admin
      KC_HOSTNAME: localhost
    ports:
      - "8080:8080"
```

Start Keycloak:

```bash
docker compose up -d keycloak
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
SSO_ISSUER_URL=http://keycloak:8080/realms/oscer
SSO_CLIENT_ID=oscer-staff
SSO_CLIENT_SECRET=<paste-secret-from-step-3>
SSO_SCOPES=openid profile email groups
```

**Note:** Use `keycloak:8080` (Docker service name) for `SSO_ISSUER_URL` since both OSCER and Keycloak are on the same Docker network.

## 8. Test the Login

1. Restart OSCER: `docker compose restart web`
2. Go to http://localhost:3000/users/sign_in
3. Click **Sign in with State Account**
4. Login with `testuser` / `password`
5. You should be redirected back and logged in as a caseworker

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `Connection refused` | Keycloak not running | Run `docker compose up -d keycloak` |
| `404` on discovery | Realm doesn't exist | Create the `oscer` realm |
| `Invalid scopes` | Missing `groups` scope | Complete step 4 or remove `groups` from `SSO_SCOPES` |
| `Invalid issuer` | URL mismatch | Ensure `SSO_ISSUER_URL` uses `keycloak:8080` (Docker DNS) |
| `Access denied` | User not in a mapped group | Add user to `OSCER-Admin` or `OSCER-Caseworker` group |

## Stopping Keycloak

```bash
docker compose stop keycloak
```

To persist data between restarts, add a volume to docker-compose.yml:

```yaml
services:
  keycloak:
    # ... other config ...
    volumes:
      - keycloak_data:/opt/keycloak/data

volumes:
  keycloak_data:
```
