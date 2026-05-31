# LockedCV-APP Account API Token 與 Google SSO 實作計畫

## 問題與目標

- 本週 App 目標是支援 limited-scope account API key 與 Google OAuth 2.0 / OIDC SSO。
- Account information view 需要顯示可從 command line 使用的 limited-scope API key。
- App 需要清理舊 session data，避免使用沒有 scope 的舊 auth token。
- App 需要啟動與完成 Google OAuth browser flow：
  1. 使用者點 Google login link。
  2. App redirect 到 Google authorization endpoint。
  3. Google redirect 回 App callback，帶 authorization `code`。
  4. App 用 `GOOGLE_CLIENT_ID`、`GOOGLE_CLIENT_SECRET`、`code` POST 到 Google token endpoint，取得 `id_token`。
  5. App 取得 Google JWKS。
  6. App 把 `id_token` 與 JWKS 送到 API `POST /api/v1/auth/sso`。
  7. API 驗證後回傳 LockedCV account 與 full-scope auth token，App 建立 session。
- 不使用 Google packaged gems；只用 `http` 與 `jwt` gems / standard library。

## 現況分析（2026-05-31）

- 專案：`LockedCV-APP`
- 目前已有：
  - `ApiClient` 支援 Bearer token。
  - `AuthenticateAccount` service：帳密登入，解析 API 回傳 `auth_token`。
  - `Account` / `CurrentSession`：保存 account info 與 API auth token。
  - Account profile page：`GET /account/:username`。
  - `FindAccount` service：呼叫 `GET /api/v1/account` 取得 current account profile。
  - `SecureSession`：保存 encrypted session values。
  - Forms：login、registration、profile、password、settings、attachment upload。
  - Attachment policy summary UI 已開始接入。
- 目前尚未有：
  - Account view 顯示 API key。
  - App-side API key copy/CLI guidance UI。
  - Session token scope 相容處理。
  - Google OAuth config。
  - Google login route / callback route。
  - OAuth `state` 防 CSRF。
  - Google token exchange service。
  - Google JWKS fetch service。
  - SSO API service：POST `/auth/sso`。
  - SSO login specs。

## 設計決策草案

- **API key 來源**：API owns token signing；App 只顯示 API 回傳的 limited-scope `api_key`，不自行產生 API token。
- **API key scope**：初版顯示 read-only scope，例如 `account:read attachments:read` 或 API 決定的 scope string。
- **Session scope compatibility**：若 API 開始要求 token scope，舊 session 裡的 token 可能無 scope。App 可以在部署後清 session，或偵測 API 401 後提示重新登入。
- **Google OAuth strategy**：App 做完整 browser OAuth flow 和 Google token exchange；API 只驗證 `id_token` 並建立/登入 account。
- **State token**：App 必須產生並保存 OAuth `state`，callback 時比對，避免 CSRF。
- **OAuth session storage**：`state` 可以暫存在 secure session；不要把 `client_secret`、`id_token`、Google access token 寫入 logs 或長期 session。
- **Google access_token**：作業說可忽略；App 只需要 `id_token`。
- **JWKS handling**：依作業說明，App 可 GET Google JWKS 後 POST 給 API。若後續改 API fetch/cache JWKS，再調整。

## 實作策略（分階段）

1. **Config and session compatibility**：補 Google config vars、舊 auth token handling strategy。
2. **Account API key display**：讀 API 回傳的 `api_key` / `api_key_scope`，在 account view 顯示與 CLI example。
3. **OAuth state service**：建立 state token 產生/驗證 helper。
4. **Google OAuth start route**：新增 `GET /auth/sso/google`，redirect 到 Google authorization endpoint。
5. **Google OAuth callback route**：新增 callback route，驗證 state，交換 code 取得 `id_token`。
6. **Google JWKS fetch**：GET Google JWKS endpoint。
7. **SSO API service**：把 `id_token` 與 JWKS POST 到 LockedCV-API。
8. **Session login**：API SSO 成功後重用 `Account` / `CurrentSession` 建立登入狀態。
9. **Tests and docs**：WebMock Google endpoints 與 API SSO endpoint，更新 README/copilot/local。

## Todo 清單

1. `config-google-oauth`
   - 更新 `config/secrets.example.yml` 與 docs，加入：
     - `GOOGLE_CLIENT_ID`
     - `GOOGLE_CLIENT_SECRET`
     - `GOOGLE_REDIRECT_URI`
     - `GOOGLE_AUTH_URL`
     - `GOOGLE_TOKEN_URL`
     - `GOOGLE_JWKS_URL`
   - `GOOGLE_REDIRECT_URI` development 可為：

     ```text
     http://localhost:9292/auth/sso/google/callback
     ```

   - Production callback URL 要在 Google Developer Console 註冊。

2. `clear-old-session-strategy`
   - 因 API token 將加入 scope，舊 session token 可能不含 scope。
   - 選一種策略：
     - deployment 時清 Redis/session store。
     - App 偵測 API `401` 後自動 logout 並提示重新登入。
     - `CurrentSession` 加 token version/scope presence check（若可解析）。
   - 文件明確提醒部署時可能需要 wipe sessions。

3. `account-api-key-model-and-view`
   - 更新 `FindAccount` / account parser，讀 API 回傳：

     ```json
     {
       "api_key": "...",
       "api_key_scope": "account:read attachments:read"
     }
     ```

   - 更新 account view 顯示 API key、scope、CLI example。
   - API key 欄位應避免被不小心放入 edit form payload。
   - UI 可先使用 readonly input 或 masked display + copy button。
   - Tests：profile page 顯示 scope 和 command example。

4. `oauth-state-helper`
   - 新增 helper/service 產生 random `state`。
   - 存到 secure session。
   - Callback 時驗證 state 並消耗。
   - Specs：valid state、missing state、mismatch state。

5. `google-sso-start-route`
   - 新增 `GET /auth/sso/google`。
   - Redirect 到 Google authorization URL，query 包含：
     - `client_id`
     - `redirect_uri`
     - `response_type=code`
     - `scope=openid email profile`
     - `state`
   - 不需要登入即可使用。
   - Tests：redirect URL 包含必要 query。

6. `google-token-exchange-service`
   - 新增 service，例如 `ExchangeGoogleAuthCode`。
   - POST 到 Google token endpoint。
   - Request 包含：
     - `client_id`
     - `client_secret`
     - `code`
     - `grant_type=authorization_code`
     - `redirect_uri`
   - 解析 response 取得 `id_token`。
   - 不保存 Google access token。
   - WebMock specs：success、Google error、missing id_token、network error。

7. `google-jwks-service`
   - 新增 service，例如 `FetchGoogleJwks`。
   - GET Google JWKS URL。
   - Parse JSON，回傳 JWKS hash 給 SSO API service。
   - 可先不做 caching；若 API 改成自己 fetch/cache，這個 service 可移除。
   - WebMock specs：success、invalid JSON、network error。

8. `authenticate-sso-service`
   - 新增 App service，例如 `AuthenticateSsoAccount`。
   - POST 到 API：

     ```text
     POST /api/v1/auth/sso
     ```

   - Body:

     ```json
     {
       "provider": "google",
       "id_token": "...",
       "jwks": {}
     }
     ```

   - Response parsing 與 `AuthenticateAccount` 一致：取出 account attributes 與 API `auth_token`。
   - Errors：
     - API 400/401 -> unauthorized/user-facing SSO failure。
     - API 5xx/network -> service unavailable。
   - Specs：success、invalid token、API unavailable。

9. `google-sso-callback-route`
   - 新增 `GET /auth/sso/google/callback`。
   - 處理 Google callback params：
     - `code`
     - `state`
     - `error`
   - 驗證 state。
   - 用 code 換 id_token。
   - 取得 JWKS。
   - POST id_token + JWKS 到 API。
   - 成功後寫入 `CurrentSession`，redirect home。
   - 失敗時 flash error，redirect `/` 或 login modal。
   - Specs：happy path、state mismatch、Google error、API rejects id_token。

10. `sso-login-ui`
    - 在 login modal 或 public home 加 Google SSO button/link。
    - Button 連到 `/auth/sso/google`。
    - 不要在 UI 中顯示 OAuth implementation details。
    - 若 Google config missing，development 可隱藏或顯示 disabled 狀態；production 應設定完整 config。

11. `docs-and-handoff`
    - 更新 README：
      - Google OAuth developer app setup。
      - callback URL。
      - required config vars。
      - session reset note for scoped tokens。
    - 更新 `.github/copilot-instructions.md`。
    - 更新 `local.md` handoff notes。

## App Routes 草案

### API key display

```text
GET /account/:username
```

Displays current account details and limited API key returned by API.

### Google SSO start

```text
GET /auth/sso/google
```

Redirects browser to Google:

```text
https://accounts.google.com/o/oauth2/v2/auth?client_id=...&redirect_uri=...&response_type=code&scope=openid+email+profile&state=...
```

### Google SSO callback

```text
GET /auth/sso/google/callback?code=...&state=...
```

Completes OAuth token exchange, sends `id_token` + JWKS to API, and logs the user in.

## API Contract 草案（App 使用）

### Current account includes API key

```text
GET /api/v1/account
Authorization: Bearer <session-token>
```

Expected account attributes may include:

```json
{
  "api_key": "limited-scope-token",
  "api_key_scope": "account:read attachments:read"
}
```

### SSO authenticate

```text
POST /api/v1/auth/sso
```

Request:

```json
{
  "provider": "google",
  "id_token": "<google-id-token>",
  "jwks": {
    "keys": []
  }
}
```

Success response shape matches password login:

```json
{
  "data": {
    "type": "authenticated_account",
    "attributes": {
      "id": "account-uuid",
      "username": "ada-lovelace",
      "email": "ada@example.com",
      "roles": ["member"],
      "auth_token": "api-session-token"
    }
  }
}
```

## 依賴順序

- API `AuthToken` scope payload -> App old-session strategy。
- API current account API key response -> App account API key display。
- `config-google-oauth` -> `google-sso-start-route` / `google-token-exchange-service`。
- `oauth-state-helper` -> `google-sso-start-route` -> `google-sso-callback-route`。
- `google-token-exchange-service` + `google-jwks-service` + API `POST /auth/sso` -> `authenticate-sso-service`。
- `authenticate-sso-service` -> `google-sso-callback-route`。

## 待組內決策

- API key 是否直接顯示完整 token，或用 masked display + copy button。
- API key 是否每次頁面刷新都變，或 API 持久化並可 revoke/rotate。
- Limited API key scope 字串最終用 `account:read attachments:read`、`*:read`，或其他課程格式。
- 舊 session 無 scope token 的處理方式：強制 logout、Redis wipe、或 API fallback。
- Google redirect URI 在 development/production 的正式值。
- SSO login button 放在 login modal、register page，或 public home。
- Google JWKS 由 App fetch 後送 API，或 API 自行 fetch/cache。
- SSO account username 由 API 產生還是 App 傳入。

## 本週完成定義

- Account information view 顯示 limited-scope API key 與 scope。
- 使用者可以複製 API key，並用 CLI 呼叫 limited-scope API route。
- App 能處理舊無 scope token 的 session 相容問題或清楚要求重新登入。
- App 有 Google SSO start/callback routes。
- App 使用 HTTP requests 完成 Google authorization code exchange，不使用 Google packaged gems。
- App 取得 Google `id_token` 與 JWKS，送 API `POST /api/v1/auth/sso`。
- API SSO 成功後，App 建立與一般登入相同的 `CurrentSession`。
- SSO flow、API key display、session reset behavior 有 specs/docs。
