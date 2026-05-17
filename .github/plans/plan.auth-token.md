# LockedCV-APP Email Verification 與 Auth Token 實作計畫

## 問題與目標

- 本週 App 目標是把目前直接建立 account 的 registration flow 改成 email verification flow。
- 使用者一開始只輸入 username 與 email；App 確認 API 回報可用後，產生 encrypted registration token 與 verification URL。
- App 將 username、email、verification URL 送到 API，由 API 呼叫 email provider 寄信。
- 使用者點擊 verification URL 回到 App 後，App 驗證 registration token，再要求使用者設定 password，最後呼叫 API 建立 account。
- 登入後 App 要保存 API 回傳的 auth token，並在每個 API request 加上 `HTTP_AUTHENTICATION: Bearer <TOKEN>`。
- App 取得 resources index 時不可把 requesting user id 或 username 傳給 API；API 應直接從 token 找 current account。

## 現況分析（2026-05-17）

- 專案：`LockedCV-APP`
- 目前已有：
  - Roda/Slim App foundation。
  - `SecureMessage` 與 `SecureSession`。
  - `ApiClient`、WebMock service tests。
  - login/logout flow。
  - registration form 目前直接收 username/email/password 並呼叫 API 建立 account。
  - session 目前保存 safe account data。
  - `Account` model：包住 API account info envelope 與 auth token。
  - `CurrentSession` model：透過 `SecureSession` 分開保存 account info 與 auth token。
  - document history 目前透過 account id 呼叫 API。
- 目前尚未有：
  - `RegistrationToken` library。
  - email verification URL flow。
  - password setup after token verification。
  - ApiClient Bearer token support。
  - token-scoped resources index flow。

## 設計決策草案

- **RegistrationToken 放 App**：App 產生與驗證 token，payload 包含 username/email。這符合 verification URL 回 App 的流程。
- **Email provider 由 API 呼叫**：App 不持有 provider API key，只把 verification URL 交給 API。
- **不建立 pending account**：使用者點擊 verification URL 並設定 password 後，App 才呼叫 API 建立正式 account。
- **Auth token 放 secure session**：登入成功後，App 用 `CurrentSession` 存放 account data 與 auth token，底層沿用 `SecureSession`。
- **ApiClient 統一帶 token**：所有需要登入身份的 service 都透過 ApiClient 帶 Bearer token，不在 service 各自組 header。

## 實作策略（分階段）

1. **Registration token library**：建立 token encode/decode，先重用 `SecureMessage`。
2. **Registration start flow**：改 registration 第一階段只收 username/email，呼叫 API availability check。
3. **Verification email request**：App 產生 verification URL，送到 API 要求寄信。
4. **Registration verify/password flow**：使用者從 email 回 App 後，App 驗證 token、顯示 password form，再呼叫 API 建立 account。
5. **Session models**：新增 `Account` 與 `CurrentSession`，讓 controller 不直接操作 raw session hash。
6. **Token-aware API client**：登入後保存 auth token，API-facing service 呼叫時自動帶 Bearer header。
7. **Owned resources index page**：更新 resources/document list flow，不送 requesting user id，改呼叫 token-scoped API endpoint。
8. **WebMock tests**：補 registration email request、token handling、Bearer header、resources index service tests。

## Todo 清單

1. `registration-token-library`
   - 新增 `RegistrationToken` library。
   - Payload 至少包含 `username`、`email`。
   - 使用 `SecureMessage` 加密/decrypt token。
   - 解密失敗、payload 缺欄位、格式錯誤要回清楚錯誤。
   - Bonus：加入 `exp` expiration timestamp，讓 registration token 也會過期。
   - 補 unit specs：round trip、tampered token、missing fields、expired token（若做 bonus）。

2. `registration-start-page`
   - 調整 `GET /auth/register` 顯示 username/email 表單，不先要求 password。
   - `POST /auth/register` 改為 registration start action。
   - 呼叫 API `POST /accounts/registration/check` 檢查 username/email availability。
   - 保留 duplicate username/email 的 user-facing error。
   - 成功後產生 verification URL。

3. `request-verification-email-service`
   - 新增 App service：把 `username`、`email`、`verification_url` 送到 API。
   - 建議 API path：`POST /accounts/registration/verification`。
   - 成功後顯示「請檢查 email」頁面或 flash。
   - API unavailable/provider failure 時顯示可重試的錯誤。
   - 用 WebMock 測試 request body 與 error handling。

4. `registration-verify-password-flow`
   - 新增 route：`GET /auth/register/verify?token=...`。
   - App decode registration token；成功時顯示 password/password confirmation form。
   - 新增 route：`POST /auth/register/verify` 或同等設計。
   - 驗證 password confirmation。
   - 呼叫現有/更新後的 `RegisterAccount` service 建立 account。
   - 建立成功後 redirect login，讓使用者重新登入。
   - 避免把 token 明文 log 出來。

5. ✅ `account-session-model`（已完成）
   - 已新增 App-side `Account` model/value object。
   - `Account` 包住 API 回傳的 account info envelope 與 auth token，不加入 DB/migration。
   - 已提供 `logged_in?`、`logged_out?`、`id`、`username`、`email`、`roles`、`admin?`、`member?`。
   - 不存 password/password_digest/encrypted/hash columns。

6. ✅ `current-session-model`（已完成）
   - 已新增 `CurrentSession` model/wrapper。
   - 已透過 `SecureSession` 分開保存/讀取/delete `:account` 與 `:auth_token`。
   - Controller 遷移到 `CurrentSession` 留到下一個 commit。

7. `authenticate-account-token`
   - 更新 `AuthenticateAccount` service，讀取 API authentication response 中的 `auth_token`。
   - 登入成功後把 token 存入 `CurrentSession`。
   - 登出時清除 account data 與 token。
   - 補 WebMock tests 確認 token 被保存，不外洩到 flash/log。

8. `api-client-bearer-token`
   - 擴充 `ApiClient` 支援 optional auth token。
   - 需要授權的 calls 加上：

     ```text
     HTTP_AUTHENTICATION: Bearer <TOKEN>
     ```

   - 避免每個 service 手寫 header。
   - 測試 `GET`、`POST`、`PUT`、`DELETE` 帶 token 的 request contract。

9. `update-api-facing-services`
   - 更新會讀寫 account-owned resources 的 services，改用 token。
   - 移除 requesting user id/current account id 作為一般 resource request 的身份來源。
   - Admin routes 若 API 仍需要 target username/account id，僅用於 target，不用於 caller identity。
   - 更新 service specs。

10. `owned-resources-index`
    - 新增或更新 document/resources index 頁面。
    - App 呼叫 token-scoped API endpoint，例如 `GET /attachments` 或 `GET /resources`。
    - 不在 request path/query/body 放 requesting user's username/account id。
    - 顯示使用者擁有的 resources list。
    - 補 WebMock tests 確認 request 不包含 account id，且有 Bearer header。

## App Routes 草案

- `GET /auth/register`
  - 顯示 username/email registration start form。
- `POST /auth/register`
  - 檢查 availability，要求 API 寄 verification email。
- `GET /auth/register/verify?token=...`
  - 驗證 token，顯示 password setup form。
- `POST /auth/register/verify`
  - 建立正式 account。
- `GET /account/:username`
  - 顯示 account overview 與 owned resources index。

## API Contract 草案（App 使用）

### Registration availability

```text
POST /api/v1/accounts/registration/check
```

### Request verification email

```text
POST /api/v1/accounts/registration/verification
```

### Login returns auth token

```text
POST /api/v1/auth/authenticate
```

Expected attributes include:

```json
{
  "id": "account-uuid",
  "username": "jane_smith",
  "email": "jane@example.com",
  "roles": ["member"],
  "auth_token": "encrypted-token"
}
```

### Authorized resource request

```text
HTTP_AUTHENTICATION: Bearer <TOKEN>
```

## 依賴順序

- API `registration-availability-api` -> App `registration-start-page`
- App `registration-token-library` -> App `registration-start-page`
- API `registration-verification-email-api` -> App `request-verification-email-service`
- App `registration-token-library` -> App `registration-verify-password-flow`
- API `authenticate-response-token` -> App `authenticate-account-token`
- App `account-session-model` -> App `current-session-model`
- App `current-session-model` -> App `api-client-bearer-token`
- API `owned-resources-index` -> App `owned-resources-index`

## 待組內決策

- Email provider 最終由 API 還是 App 呼叫；本計畫暫定 API。
- Email provider 選擇與 API key 設定方式。
- Registration token expiration 是否列入本週必做或 bonus。
- Auth token expiration 後 App UX：直接 logout、redirect login、或提示 session expired。
- `Account` / `CurrentSession` 檔案放在 `app/models` 還是 `app/lib`；它們不是 DB model。
- Resources index 的正式 domain 命名與 UI 呈現。

## 本週完成定義

- 使用者可輸入 username/email，收到 verification email。
- 使用者點 verification URL 回 App 後可以設定 password 並建立正式 account。
- 未驗證 email 前，API DB 不會有 temporary account row。
- 登入後 App secure session 內有 account data 與 auth token。
- App 對需要授權的 API request 都會帶 Bearer token。
- App 顯示 owned resources index，且 request 不包含 requesting user id/username。
- Registration token、API-facing services、Bearer header 都有測試。
