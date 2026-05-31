# LockedCV-APP Copilot Instructions

This file provides guidance to AI coding assistants and teammates working on
the LockedCV Web App.

## Startup Context for AI Assistants

Before making changes, read:

1. `README.md`
2. `.github/copilot-instructions.md`
3. `local.md` if it exists in the repo root

`local.md` is intentionally gitignored. It is for local handoff notes such as
current task status, user preferences, deployment reminders, or decisions not
ready to commit.

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
- Use form contracts under `app/forms/` for web form validation. Controllers
  should pass raw `routing.params` to form contracts, then pass validated values
  to services.
- Keep form-only fields, such as password confirmations, out of service/API
  payloads after form validation succeeds.
- Keep API URLs configurable through `config/secrets.yml`, not hardcoded in
  controllers or views.
- Use `Account` and `CurrentSession` for logged-in account/session state.
- Store only non-sensitive account data and the API-issued auth token in secure
  session storage.
- Do not store passwords, password digests, encrypted columns, or hash lookup
  values in session data.
- Use `ApiClient` with `auth_token:` for authorized API calls. It sends
  `Authorization: Bearer <TOKEN>` via `HTTP.auth`.
- API authorization is the security boundary. App-side role checks are for
  navigation, button visibility, and user flow only.
- Services should focus on API payload shaping, API calls, API response parsing,
  and API error mapping. Avoid duplicating form-shape validation in services
  when a controller already validated the request with a form contract.
- App models under `app/models/` should parse API envelopes and expose readable
  view helpers. For attachments, use `Attachment#can_delete?` rather than
  reading the raw API policy hash in views.

## Expected Routes

- `GET /` renders the public home page or the logged-in CV vault.
- `POST /auth/login` authenticates against `LockedCV-API`.
- `GET /auth/register` renders the registration form.
- `POST /auth/register` checks availability, creates a registration token, and
  asks `LockedCV-API` to send the verification email.
- `GET /auth/register/:registration_token` renders the final account creation
  form after the user follows the email link.
- `POST /auth/register/:registration_token` creates the account through
  `LockedCV-API`.
- `POST /attachments/upload` forwards a selected PDF to `LockedCV-API`.
- `POST /attachments/:attachment_id/delete` deletes an attachment through
  `LockedCV-API`.
- `GET /account/:username` renders the logged-in account overview.
- `GET /account/:username/edit` renders the editable account profile form.
- `POST /account/:username` updates editable account profile fields through
  `LockedCV-API`.
- `GET /account/:username/password` renders the password change form.
- `POST /account/:username/password` changes the password through
  `LockedCV-API` and clears the current session on success.
- `GET /settings` renders admin account settings.
- `POST /settings` updates a user's system role through `LockedCV-API`.
- `POST /settings/accounts/:account_id/delete` deletes an account through
  `LockedCV-API` for admins.
- `GET /auth/logout` clears session account data.

`GET /auth/login` currently redirects to `/#login-modal`; the login form is
presented from the home page login modal.

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
      "roles": ["member"],
      "auth_token": "encrypted-token"
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

- `POST /api/v1/accounts/registration/check` before requesting a verification
  email.
- `POST /api/v1/auth/register` to ask the API to send the Mailgun verification
  email.
- `POST /api/v1/accounts` for registration.
- `GET /api/v1/account` for current account profile data.
- `PUT /api/v1/account` for current account profile updates.
- `PUT /api/v1/account/password` for current account password changes.
- `GET /api/v1/attachments` for current account document history.
- `POST /api/v1/attachments/upload` for current account attachment upload.
- `DELETE /api/v1/attachments/:attachment_id` for current account attachment
  delete.
- `GET /api/v1/accounts` for admin account listing.
- `DELETE /api/v1/accounts/:target_account_id` for admin account deletion.
- `PUT /api/v1/accounts/:target_username/system_roles/:role_name` for admin
  role updates.

Current-user calls should prefer token-scoped API paths and should not put the
requesting user's id or username in the API path/query/body. Target id/username
is acceptable for admin actions.

`GET /api/v1/attachments` returns attachment resource envelopes with policy
summaries. `ListAttachments` converts each entry into an `Attachment` app model;
views should use model predicates such as `can_delete?` to decide whether to
show actions.

## Development Boundary

This branch has the authenticated-session Web App foundation in place:

- Roda app bootstrapping
- API service client
- login/logout flow
- basic registration flow
- profile update flow
- change password flow
- admin settings flow
- admin account delete flow
- document history from the API
- attachment list parsing through the `Attachment` app model
- policy-summary driven attachment delete visibility
- attachment upload/delete forwarding to the API
- email verification registration flow
- encrypted registration tokens containing email/username
- cookie-backed session
- flash notices/errors
- role-aware view hooks
- WebMock service tests

Registration, email verification kickoff/confirmation, profile update, password
change, admin lookup/update/delete, auth token session storage, and bearer-token
API calls are implemented. Registration tokens currently do not expire.

## Validation

Run tests before handing off:

```bash
bundle exec rake spec
```

Run style checks before handing off:

```bash
bundle exec rubocop --cache false .
```
