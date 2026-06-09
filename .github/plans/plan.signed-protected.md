# LockedCV-APP Signed Requests 與 Browser Protection 實作計畫

## 問題與目標

- 本週 App 目標有三塊：
  - Google OAuth CSRF prevention：用 `state` nonce 防止 callback 被偽造。
  - Signed client requests：對沒有 bearer token 的 API POST request 簽章，讓 API 能信任 request 來自 LockedCV-APP。
  - Browser protection：用 security headers / CSP / cookie flags 降低 XSS、code injection、CSRF、clickjacking、未驗證 assets 等風險。
- 第一點 Google OAuth `state` nonce 目前已完成；本 plan 會記錄現況，不重做。
- 這週主要未完成的是 request signing、`security.rb`、CSP compliance、以及第三方資源 integrity audit。

## 現況分析（更新：2026-06-09）

- 專案：`LockedCV-APP`
- 目前已有：
  - Google SSO start route：`GET /auth/sso/google`。
  - Google SSO callback route：`GET /auth/sso/google/callback`。
  - OAuth `state` nonce：
    - start route 產生 `SecureRandom.hex(16)`。
    - 存到 `session['sso_state']`。
    - callback 從 URL params 取回 `state`。
    - callback 用 `session.delete('sso_state')` 取出 expected state 並比對。
  - `rbnacl` 與 `base64` gems。
  - `ApiClient` 與多個 service 呼叫 API。
- 目前尚未有：
  - `SignedMessage` library。
  - App-side `SIGNING_KEY` config。
  - pre-login API service 的 signed body。
  - `secure_headers` gem 與 `app/controllers/security.rb`。
  - CSP violation reporting route。
- CSP 前置風險：
  - `app/presentation/views/home.slim` 有 inline `javascript:`。
  - `app/presentation/views/attachment_scan.slim` 有 inline `javascript:` 與大量 inline `style=`。
  - 若直接加 strict CSP 且不允許 `'unsafe-inline'`，這些頁面會壞掉。

## 設計決策草案

- **Google OAuth state**：已完成，後續只補 docs/spec 維護；不要把 state 驗證移到 API，因為 OAuth browser callback 發生在 App。
- **Signing key topology**：
  - App 保存 private `SIGNING_KEY`。
  - API 保存 public `VERIFY_KEY`。
  - production signing key 只應存在 App Heroku config vars。
- **Signing boundary**：
  - 初版只簽沒有 bearer token 的 API POST。
  - Authenticated routes 繼續使用 bearer token + API policy。
- **Signed body shape**：

  ```json
  {
    "data": {},
    "signature": "base64-ed25519-signature"
  }
  ```

- **CSP approach**：
  - 優先移除 inline JavaScript / inline style。
  - 不把 `'unsafe-inline'` 當成長期解法，否則 CSP 對 XSS 的價值會大幅下降。
  - 如果有很難外移的少量 script，再評估 nonce，但初版以 external asset 為主。

## 需要簽章的 App services

這些 service 發出的 API POST 在呼叫時還沒有 bearer token，或是 request 本身是在取得 session token 前：

- `app/services/authenticate_account.rb`
  - `POST /api/v1/auth/authenticate`
- `app/services/verify_registration.rb`
  - `POST /api/v1/accounts/registration/check`
  - `POST /api/v1/auth/register`
- `app/services/register_account.rb`
  - `POST /api/v1/accounts`
- `app/services/authenticate_google_sso.rb`
  - `POST /api/v1/auth/sso`

暫時不需要簽章的例子：

- upload attachment。
- create masked PDF。
- preview / export masked PDF。
- change password / profile update。

這些 route 已經有 bearer token，最低作業要求不需要在第一版也簽章。

## 實作策略（分階段）

1. **SignedMessage library**
   - 新增 `app/lib/signed_message.rb`。
   - 提供：
     - `.setup(signing_key64)`
     - `.sign(message)` -> `{ data: message, signature: signature64 }`
   - 使用 `RbNaCl::SigningKey` 與 `Base64.strict_encode64`。
   - 補 unit specs：output shape、signature 可被 verify key 驗證、tampered data 驗證失敗、missing key raise。

2. **Config and secrets**
   - `config/environments.rb` setup `SignedMessage`。
   - `config/secrets.example.yml` 加入 `SIGNING_KEY`。
   - Heroku APP 需要加 `SIGNING_KEY`。
   - Heroku API 需要加對應的 `VERIFY_KEY`。

3. **Sign pre-login services**
   - 在 service call site 包 body：

     ```ruby
     @client.post('/auth/authenticate', SignedMessage.sign(credentials))
     ```

   - 不改 `ApiClient` 預設行為，避免所有 POST 都被強迫 signed。
   - 更新 WebMock specs，expected body 要改成 signed wrapper。
   - 保留 form validation 與 service error handling 現有邏輯。

4. **Google OAuth state regression**
   - 確認既有 specs 已覆蓋：
     - start route 會把 state 放進 Google authorization URL。
     - callback state mismatch 會停止登入。
     - callback state missing 會停止登入。
     - 成功後 state 會被消耗。
   - 若缺其中一項，再補 regression spec。

5. **Security controller**
   - 新增 `app/controllers/security.rb`。
   - 使用 `secure_headers` middleware。
   - 設定：
     - `X-Frame-Options: DENY`
     - `X-Content-Type-Options: nosniff`
     - `X-XSS-Protection: 1`
     - `X-Permitted-Cross-Domain-Policies: none`
     - `Referrer-Policy`
     - Content-Security-Policy
   - 新增 CSP report route：

     ```text
     POST /security/report_csp_violation
     ```

   - report route 記錄 violation 後回空 response。

6. **Session and cookie hardening**
   - session cookie 設：
     - `httponly: true`
     - `same_site: :lax`
     - production 才加 `secure: true`，避免 local HTTP 無法保存 session。
   - 檢查目前 `config/environments.rb` 與 `app/controllers/app.rb` 裡和 HTTPS/security 相關的設定。
   - 依作業要求，把適合集中管理的 security code 移到 `app/controllers/security.rb`；production HTTPS redirect 若仍需留在 environment/plugin，plan 中要註明原因。

7. **CSP compliance refactor**
   - `home.slim` inline upload JavaScript 移到 self-hosted JS asset。
   - `attachment_scan.slim` inline preview/masking JavaScript 移到 self-hosted JS asset。
   - `attachment_scan.slim` inline `style=` 移到 CSS class 或 data attribute。
   - Layout 載入 App 自己的 JS asset，CSP `script-src` 允許 `'self'`。
   - 不使用 `'unsafe-inline'` 作為最終狀態。

8. **Third-party asset integrity**
   - Audit layout / partials 是否載入 CDN scripts、styles、fonts。
   - 若有第三方 asset：
     - 加上 `integrity`。
     - 加上 `crossorigin`。
     - CSP allowlist 只放必要 domain。
   - 若目前沒有第三方 scripts/styles/fonts，文件中記錄「目前無 CDN asset；若未來新增需加 SRI」。
   - 可考慮新增 rake task 產生 URL integrity hash，但若 repo 目前沒有 CDN asset，可先列為 optional。

9. **Manual smoke**
   - Login。
   - Registration email request。
   - Registration confirm 建帳。
   - Google SSO。
   - Attachment upload。
   - Masked PDF preview / export / encrypted download。
   - Browser console 確認沒有 CSP violation。
   - 故意觸發一次 CSP violation，確認 `/security/report_csp_violation` 有收到。

## App / API Contract 草案

App 對 API 發出的 pre-login POST：

```json
{
  "data": {
    "email": "vick@example.com",
    "password": "password"
  },
  "signature": "base64-ed25519-signature"
}
```

API 驗章成功後，controller/service 只看到 `data` 內容。

## Out of Scope

- Per-form CSRF token。
- Request replay protection。
- Signed API responses。
- Bearer-authenticated routes 的 request signing。
- 多 client signing key registry。
- CSP `report-to` Reporting API migration。
- UI/UX 大改版。

## 完成定義

- OAuth state nonce 已有 regression specs。
- APP 有 `SignedMessage` library。
- Login、registration、registration check、account create、Google SSO request 都用 signed wrapper 呼叫 API。
- APP 有 `app/controllers/security.rb`，並啟用 security headers、cookie flags、CSP、CSP report route。
- Strict CSP 不依賴 `'unsafe-inline'`，主要頁面功能仍可使用。
- 第三方 assets 已確認 SRI 狀態。
- README / local handoff 後續需要補上 key split、Google Console / Heroku 設定、manual smoke checklist。

## Commit Message 草案

若拆三個 commits：

```text
feat: sign unauthenticated API requests
feat: configure browser security headers and CSP
docs: document signed request deployment setup
```

若 CSP inline cleanup 較大，也可以拆成：

```text
refactor: move inline browser code into app assets
feat: enforce browser security headers
```
