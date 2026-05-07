# LockedCV-APP Authenticated Sessions 實作計畫

## 問題與目標

- 本週 App 目標是建立 server-rendered Web App 的登入/session 基礎。
- App 需呼叫 `LockedCV-API` 的 `POST /api/v1/auth/authenticate` 進行帳密驗證。
- 登入成功後，App 用 cookie-based session 保存非敏感 account data。
- App 需要 flash notices/errors，讓 login/logout/unauthorized flow 有清楚轉場。
- 本階段做到 design-ready minimal views；正式 UI 美化與完整頁面設計留到 UI/design phase。

## 現況分析（2026-05-03）

- 專案：`LockedCV-APP`
- 目前 repo 幾乎是空 repo，只有 `LICENSE`。
- API repo 已完成：
  - `POST /api/v1/auth/authenticate`
  - authentication success response：account id、username、email、roles
  - authentication failure：`403` JSON
  - `SECURE_SCHEME` / TLS scheme check
  - minimal admin-only system role assignment demo
- App 不應直接連 database，也不應複製 API models/migrations。

## 實作策略（分階段）

1. **App foundation**：建立 Roda/Slim app skeleton，能啟動並 render home。
2. **Configuration and sessions**：建立 config/secrets、session secret、cookie session。
3. **API service client**：建立共用 HTTP client，集中處理 API URL、JSON parsing、non-2xx errors。
4. **Authentication service**：建立 App-side service object 呼叫 API authenticate route。
5. **Login/logout controllers**：建立 `/auth/login` 與 `/auth/logout` flow。
6. **Account overview**：建立登入後 account page，讀取 session 中的 safe account data。
7. **Flash messages**：加入 flash plugin 與 layout flash bar。
8. **Role-aware view hooks**：先用 session roles 控制 minimal links/buttons 顯示，不把 UI hide/show 當作安全邊界。
9. **Manual verification**：用本機 API + App 跑完整登入/登出流程。

## Todo 清單

1. ✅ `app-foundation`（已完成）
   - 新增 `Gemfile`、`.ruby-version`、`config.ru`、`Rakefile`、`require_app.rb`。
   - 建立 `app/controllers/app.rb`。
   - 設定 Roda `render`、`multi_route`、`public/assets`（若本階段需要）。
   - 建立 minimal `home.slim`。

2. ✅ `config-and-session`（已完成）
   - 新增 `config/environments.rb`。
   - 新增 `config/secrets.example.yml`。
   - 設定 `API_URL`、`APP_URL`、`SESSION_SECRET`。
   - 使用 `Rack::Session::Cookie`。
   - 新增 `rake generate:session_secret`。

3. ✅ `api-client-service`（已完成）
   - 新增 `app/services/api_client.rb`。
   - 目前支援 `post`，足夠 authentication flow。
   - 已集中處理 JSON parse。
   - 已對 non-2xx response raise structured error，保留 status/body。

4. ✅ `authenticate-account-service`（已完成）
   - 新增 `app/services/authenticate_account.rb`。
   - 呼叫 API：`POST /auth/authenticate`（base URL 由 config 提供，例如 `http://localhost:9000/api/v1`）。
   - 成功回傳 safe account hash：`id`、`username`、`email`、`roles`。
   - 失敗時 raise App-side unauthorized error。

5. ✅ `auth-controller`（已完成）
   - 新增 `app/controllers/auth.rb`。
   - `GET /auth/login` render login form。
   - `POST /auth/login` 驗證表單 input，呼叫 authentication service。
   - 成功：寫入 `session[:current_account]`，flash notice，redirect home/account。
   - 失敗：status `400`，flash error，重新 render login。
   - `GET /auth/logout` 清除 session，flash notice，redirect login/home。

6. ✅ `account-controller`（已完成）
   - 新增 `app/controllers/account.rb`。
   - 建立 `require_login!` helper 或同等 guard。
   - `GET /account/:username` 顯示登入中的 account overview。
   - 未登入時 redirect login，並顯示 unauthorized flash。
   - 非本人頁面先 redirect 自己的 account page。
   - Admin lookup of other accounts is deferred because it requires API-level authorization policy.

7. ✅ `slim-views`（已完成）
   - 建立 `layout.slim`。
   - 建立 `nav.slim`。
   - 建立 `flash_bar.slim`。
   - 建立 `home.slim`、`login.slim`、`account.slim`。
   - Views 保持 minimal/design-ready，不做正式 UI polish。

8. ✅ `role-aware-view-hooks`（已完成）
   - 從 `session[:current_account]['roles']` 判斷 roles。
   - admin 可看到管理或 role demo 入口 placeholder。
   - member 可看到 account overview。
   - `owner`、`viewer_masked`、`viewer_full` 先作為 placeholder 或 deferred，不做完整資料頁。
   - nav 可保留 register link/label as coming soon，本階段不實作註冊流程。

9. ✅ `manual-test-checklist`（已完成）
   - 已驗證 API running。
   - 已驗證 App route smoke checks。
   - 已驗證成功登入後看到 account data。
   - 已驗證錯誤密碼顯示 flash error。
   - 已驗證 logout 後 session 被清除並顯示 notice。
   - 已驗證未登入進 account page 會 redirect login。
   - 已驗證 nav 依登入狀態切換 login/account/logout。

## API Contract

### POST `/api/v1/auth/authenticate`

Request:

```json
{
  "username": "jane_smith",
  "password": "my-secret-password"
}
```

Success `200`:

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

Failure `403`:

```json
{
  "message": "Invalid credentials"
}
```

## 不在本階段

- 正式 UI 美化與完整 visual design。
- Attachment/sensitive_data 完整頁面。
- `owner`、`viewer_masked`、`viewer_full` 的完整 resource-level workflows。
- API policy object 或完整 authorization model。
- Admin viewing or managing other accounts through App pages.
- Register form, account creation flow, and automatic post-registration login.
- App 直接存取 database。

## Deferred Authorization Work

- Admin viewing other accounts is deferred.
- API-level self/admin account lookup policy is deferred.
- Resource-level `owner`、`viewer_masked`、`viewer_full` workflows are deferred.
- This branch only uses roles for App-side navigation and UI visibility.
- API remains the final authorization boundary for any behavior that changes or exposes server-side data.

## 本週完成定義

- 使用者可以從 App login page 登入。
- App 會透過 `LockedCV-API` 驗證 credentials。
- 登入成功後，cookie session 保存 safe account data。
- 登入失敗、logout、unauthorized access 都有 flash message。
- 已登入使用者可以看到 account overview。
- navigation 會依登入狀態顯示 home/login 或 home/account/logout。
- Views 維持 minimal/design-ready，後續可進入正式 UI/design phase。
