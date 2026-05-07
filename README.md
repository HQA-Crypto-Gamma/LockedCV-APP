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

## Scope

This branch implements authenticated sessions with minimal, design-ready Slim
views:

- home page
- login form
- account overview
- logout
- flash messages
- role-aware navigation hooks

Formal UI polish, registration, admin account lookup, and resource-level
authorization workflows are deferred.

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
