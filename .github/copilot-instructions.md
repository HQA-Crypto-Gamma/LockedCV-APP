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

- `GET /` renders a minimal home page.
- `GET /auth/login` renders the login form.
- `POST /auth/login` authenticates against `LockedCV-API`.
- `GET /account/:username` renders the logged-in account overview.
- `GET /auth/logout` clears session account data.

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

## Development Boundary

This branch should complete the authenticated-session foundation before final
visual design work:

- Roda app bootstrapping
- API service client
- login/logout flow
- cookie-backed session
- flash notices/errors
- minimal Slim views
- role-aware view hooks

Formal UI polish, dashboard design, attachment/sensitive-data pages, and full
resource-level authorization can be completed after this foundation is working.

## Validation

Run available checks before handing off:

```bash
bundle exec rubocop --cache false .
```

If tests are added:

```bash
bundle exec rake spec
```
