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
- encrypted server-side session values
- API-issued auth token stored in secure session
- Redis-backed production session storage
- account overview page
- account profile edit/update flow
- change password page that logs the user out after a successful update
- document history loaded from the API
- PDF upload and attachment delete actions forwarded to the API
- admin settings page for listing accounts, updating system roles, and deleting
  accounts
- birthday validation for registration and profile updates
- flash messages and role-aware navigation

Current routes:

- `GET /`
- `POST /auth/login`
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

Email verification registration is implemented in the App. The App encrypts
`email` and `username` into a `RegistrationToken`, builds
`APP_URL/auth/register/:token`, asks the API to send that URL through Mailgun,
then creates the account after the user follows the link and completes the
confirmation form. Registration tokens are encrypted and tamper-resistant but
currently do not expire.

Attachment upload/delete actions are implemented as App routes that forward to
the API. The API owns file storage and attachment database records; this repo
does not store uploaded files or attachment metadata locally.

Current protected API calls:

- `GET /api/v1/account`
- `PUT /api/v1/account`
- `PUT /api/v1/account/password`
- `GET /api/v1/attachments`
- `POST /api/v1/accounts/registration/check`
- `POST /api/v1/auth/register`
- `POST /api/v1/accounts`
- `POST /api/v1/attachments/upload`
- `DELETE /api/v1/attachments/:attachment_id`
- `GET /api/v1/accounts` for admins
- `DELETE /api/v1/accounts/:target_account_id` for admins
- `PUT /api/v1/accounts/:target_username/system_roles/:role_name` for admins

Current-user API calls use token-scoped paths. Admin actions still include a
target account id or username because they operate on another account.

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
