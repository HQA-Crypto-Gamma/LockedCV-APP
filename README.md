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

Paste the generated value into `config/secrets.yml`.

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
- account registration page
- login and logout flow
- account overview page
- document history loaded from the API
- admin settings page for listing accounts and updating system roles
- flash messages and role-aware navigation

Current routes:

- `GET /`
- `POST /auth/login`
- `GET /auth/register`
- `POST /auth/register`
- `GET /account/:username`
- `GET /settings`
- `POST /settings`
- `GET /auth/logout`

## Scope

This branch has the main authenticated Web App foundation in place. Registration
and admin lookup/update flows exist, but account verification, stronger session
security, HTTPS enforcement, and resource-level authorization still need to be
strengthened.

## Checks

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
