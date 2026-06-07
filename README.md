# LockedCV App

Server-rendered Web App for LockedCV. This app is a thin Roda/Slim frontend
over `LockedCV-API`; the API owns persistence, password verification, PII
protection, and final authorization.

## Install

Install dependencies:

```bash
bundle install
```

Copy local secrets and generate a session secret:

```bash
cp config/secrets.example.yml config/secrets.yml
bundle exec rake generate:session_secret
```

Paste the generated value into `config/secrets.yml`. Production also needs a
Redis add-on URL exposed as `REDISCLOUD_URL` or `REDIS_URL`; development and
test sessions use the in-memory Rack session pool.

## Run

Start the API on port `9000`:

```bash
bundle exec rake run:dev
```

Run this from your local `LockedCV-API` checkout. By default, this App expects
the API at `http://localhost:9000/api/v1`; adjust `API_URL` in
`config/secrets.yml` if your API runs elsewhere.

Start the App on port `9292`:

```bash
bundle exec rake run:dev
```

Run this from this repo.

Open:

```text
http://localhost:9292
```

## Login

The App authenticates against:

```text
POST http://localhost:9000/api/v1/auth/authenticate
```

Seed or create accounts in the API before logging in. Development seed
credentials include:

```text
username: ada-lovelace
password: ada-secret

username: alan-turing
password: alan-secret
```

## Routes and Features

The App currently includes:

- public home page with login modal
- two-step email verification registration flow
- login and logout flow
- Google SSO login flow through `/auth/sso/google`
- encrypted server-side session values
- API-issued auth token stored in secure session
- Redis-backed production session storage
- account overview page
- read-only account API key display on the account overview page
- account profile edit/update flow
- change password page that logs the user out after a successful update
- document history loaded from the API
- PDF upload and attachment delete actions forwarded to the API
- admin settings page for listing accounts, updating system roles, and deleting
  accounts
- dry-validation form objects for login, registration, profile updates,
  password changes, settings role assignment, and attachment upload
- birthday validation for registration and profile updates
- attachment policy summary parsing for delete-action visibility
- flash messages and role-aware navigation

Current routes:

- `GET /`
- `POST /auth/login`
- `GET /auth/sso/google`
- `GET /auth/sso/google/callback`
- `GET /auth/register`
- `POST /auth/register`
- `GET /auth/register/:registration_token`
- `POST /auth/register/:registration_token`
- `POST /attachments/upload`
- `POST /attachments/:attachment_id/delete`
- `GET /account/:username`
- `GET /account/:username/edit`
- `POST /account/:username`
- `GET /account/:username/password`
- `POST /account/:username/password`
- `GET /settings`
- `POST /settings`
- `POST /settings/accounts/:account_id/delete`
- `GET /auth/logout`

## Scope

This branch has the main authenticated Web App foundation in place. Registration,
profile update, change password, and admin lookup/update/delete flows exist,
production sessions are Redis-backed, and HTTPS enforcement is configured.
Authenticated API calls now send `Authorization: Bearer <TOKEN>` using the
token returned by the API login response. The App uses token-scoped API paths
for current-account profile, password, and attachment-list calls, so it does not
send the requesting user's account id in those requests.
API login/session tokens are full-scope (`*:write`). The account overview page
also fetches a read-only API key (`*:read`) from
`GET /api/v1/accounts/:username` and displays it for command-line/deputy use.
If an old session token was issued before scoped tokens existed, the API treats
it as invalid and the user should log in again.

Google SSO is implemented with the App/API split used in class. The App starts
the OAuth browser flow at `GET /auth/sso/google`, stores and verifies OAuth
`state`, exchanges the callback `code` for a Google `id_token`, fetches Google
JWKS, then sends `id_token` and JWKS to API `POST /api/v1/auth/sso`. The API
verifies the token and returns the same authenticated account/session shape as
password login. The App stores that returned account/auth token in
`CurrentSession`; it does not store Google access tokens or `id_token`s.

Email verification registration is implemented in the App. The App encrypts
`email` and `username` into a `RegistrationToken`, builds
`APP_URL/auth/register/:token`, asks the API to send that URL through Mailgun,
then creates the account after the user follows the link and completes the
confirmation form. Registration tokens are encrypted and tamper-resistant but
currently do not expire.

Attachment upload/delete actions are implemented as App routes that forward to
the API. The API owns file storage and attachment database records; this repo
does not store uploaded files or attachment metadata locally.

Form input is validated in `app/forms/` before controllers call services.
Services should receive validated values and focus on API payload shaping,
Bearer-token API calls, response parsing, and API error mapping. The API remains
the final security and data-validation boundary.

Attachment list responses are parsed into App-side `Attachment` models. The
home view uses the API policy summary, currently `attachment.can_delete?`, to
hide delete actions for attachments the current account cannot delete. UI
policy checks are only a user-flow aid; the API still enforces authorization.

Current protected API calls:

- `GET /api/v1/account`
- `GET /api/v1/accounts/:username` to fetch a read-only account API key for the
  profile page
- `PUT /api/v1/account`
- `PUT /api/v1/account/password`
- `GET /api/v1/attachments`
- `POST /api/v1/accounts/registration/check`
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/sso`
- `POST /api/v1/accounts`
- `POST /api/v1/attachments/upload`
- `DELETE /api/v1/attachments/:attachment_id`
- `GET /api/v1/accounts` for admins
- `DELETE /api/v1/accounts/:target_account_id` for admins
- `PUT /api/v1/accounts/:target_username/system_roles/:role_name` for admins

Current-user API calls use token-scoped paths. Admin actions still include a
target account id or username because they operate on another account.
The profile page keeps profile data and API-key retrieval separate:
`FindAccount` calls `GET /api/v1/account`, while `GetAccountApiKey` calls
`GET /api/v1/accounts/:username` and passes the returned key to the Slim view as
an explicit `api_key` local.

## Google SSO Configuration

Development `config/secrets.yml` needs:

```yaml
APP_URL: http://localhost:9292
API_URL: http://localhost:9000/api/v1
GOOGLE_CLIENT_ID: <Google OAuth client id>
GOOGLE_CLIENT_SECRET: <Google OAuth client secret>
GOOGLE_AUTH_URL: https://accounts.google.com/o/oauth2/v2/auth
GOOGLE_TOKEN_URL: https://oauth2.googleapis.com/token
GOOGLE_JWKS_URL: https://www.googleapis.com/oauth2/v3/certs
```

For Heroku production, `APP_URL` must be the deployed App origin, and Google
Console must include:

- Authorized JavaScript origin: `https://<app-heroku-domain>`
- Authorized redirect URI:
  `https://<app-heroku-domain>/auth/sso/google/callback`

Also confirm the API Heroku app has the same `GOOGLE_CLIENT_ID`, because the
API validates `id_token` audience against that value.

## Checks

Run tests:

```bash
bundle exec rake spec
```

Run style checks:

```bash
bundle exec rubocop --cache false .
```

Manual route smoke check from console:

```bash
bundle exec rake console
get '/'
last_response.status
```
