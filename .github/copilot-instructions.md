# LockedCV-APP Copilot Instructions

This file provides guidance to AI coding assistants and teammates working on
the LockedCV Web App.

## Project Overview

LockedCV-APP is the server-rendered Web frontend for LockedCV. It is a thin
client over `LockedCV-API`; the API owns persistence, password verification,
PII encryption, and final authorization. The App owns sessions, flash messages,
form handling, and Slim view rendering.

- **Language:** Ruby
- **Framework:** Roda
- **Views:** Slim
- **API dependency:** `LockedCV-API`

## Architecture Rules

- Do not add database models, migrations, or direct SQLite access to this repo.
- Use service objects under `app/services/` for HTTP calls to the API.
- Keep API URLs configurable through `config/secrets.yml`, not hardcoded in
  controllers or views.
- Store only non-sensitive account data in cookie sessions:
  `id`, `username`, `email`, and `roles`.
- Do not store passwords, password digests, encrypted columns, or hash lookup
  values in session data.
- API authorization is the security boundary. App-side role checks are for
  navigation, button visibility, and user flow only.

## Expected Routes

- `GET /` renders the public home page or the logged-in CV vault.
- `POST /auth/login` authenticates against `LockedCV-API`.
- `GET /auth/register` renders the registration form.
- `POST /auth/register` creates an account through `LockedCV-API`.
- `GET /account/:username` renders the logged-in account overview.
- `GET /settings` renders admin account settings.
- `POST /settings` updates a user's system role through `LockedCV-API`.
- `GET /auth/logout` clears session account data.

`GET /auth/login` currently redirects to `/`; the login form is presented from
the home page login modal.

## API Contract

Authenticate through:

```text
POST /api/v1/auth/authenticate
```

Expected success response:

```json
{
  "data": {
    "type": "authenticated_account",
    "attributes": {
      "id": "account-uuid",
      "username": "jane_smith",
      "email": "jane@example.com",
      "roles": ["member"]
    }
  }
}
```

Expected failure response:

```json
{
  "message": "Invalid credentials"
}
```

Other API-facing services call:

- `POST /api/v1/accounts` for registration.
- `GET /api/v1/accounts?current_account_id=...` for admin account listing.
- `PUT /api/v1/accounts/:username/system_roles/:role_name` for admin role
  updates.
- `GET /api/v1/accounts/:account_id/attachments` for document history.

## Development Boundary

This branch has the authenticated-session Web App foundation in place:

- Roda app bootstrapping
- API service client
- login/logout flow
- basic registration flow
- admin settings flow
- document history from the API
- cookie-backed session
- flash notices/errors
- role-aware view hooks

Registration and admin lookup/update are implemented, but account verification,
stronger session security, HTTPS enforcement, WebMock service tests,
distributed session storage, and full resource-level authorization still need
to be strengthened.

## Validation

Run available checks before handing off:

```bash
bundle exec rubocop --cache false .
```

If tests are added:

```bash
bundle exec rake spec
```
