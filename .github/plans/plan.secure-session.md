# LockedCV-APP Secure Session 與部署作業實作計畫

## 問題與目標

- 本週 App 目標是把現有 Web App 從「可登入的 session foundation」強化成「可部署、可測試、session data 有加密保護」的版本。
- App 所有 route 都需要導向 HTTPS，並在 production 啟用 HSTS。
- App services 需要用 WebMock 寫基本測試，避免測試時連到真的 `LockedCV-API`。
- App 需要保留基本且風險較高的 registration workflow：從表單接收 email、username、password，再由 service object POST 到 API。
- App session data 需要先經 secure messaging library 加密後再存取。
- Development/test 使用 session pooling strategy；production 使用 Heroku RedisCloud 作為分散式 session store。
- App 部署到 Heroku 後，需要連到已部署的 API，並讓使用者能建立/更新資源。

## 現況分析（2026-05-10）

- 專案：`LockedCV-APP`
- 目前已完成 Web App foundation：Roda、Slim views、API service client、login/logout、flash、role-aware navigation。
- 目前已有基本 registration flow：
  - `GET /auth/register`
  - `POST /auth/register`
  - `RegisterAccount` service object 呼叫 API 建立帳號。
- 目前已有 admin settings flow：
  - `GET /settings`
  - `POST /settings`
  - 透過 API 列出帳號並更新 system role。
- 待強化項目：
  - HTTPS redirect 與 HSTS 尚未明確完成。
  - services 尚未用 WebMock 隔離外部 API request。
  - session data 目前仍需要加密保護。
  - session storage 尚未切換成 dev/test pool + production Redis。
  - Heroku production config 需要對齊已部署 API URL、Redis、session secret、message key。

## 實作策略（分階段）

1. **HTTPS and HSTS**：先在 App request 入口處加上 HTTPS redirect 與 HSTS header，並只在 production 強制要求 HTTPS。
2. **Service tests with WebMock**：為 API-facing services 補基本 WebMock tests，讓測試不依賴真實 API。
3. **Registration workflow review**：確認 registration form、controller、service object、API contract 與 error handling 都符合本週要求。
4. **Secure messaging**：建立 secure messaging library，使用 `MSG_KEY` 與 NaCl `SimpleBox` 加密/解密訊息。
5. **Secure session wrapper**：建立 secure session library，所有 session set/get 都透過 secure messaging library。
6. **Session pool and Redis store**：development/test 使用 pooling strategy，production 使用 Heroku RedisCloud。
7. **Heroku deployment**：建立 App dyno，設定 production secrets，確認 App 指向 deployed API。
8. **Production smoke checks**：部署後確認 registration、login、settings role update 等使用者流程可寫入雲端資源。

## Todo 清單

1. `app-https-hsts`
   - ⬜ 在 production 環境把 HTTP request redirect 到 HTTPS。
   - ⬜ 為所有 production response 加上 `Strict-Transport-Security` header。
   - ⬜ 確認 Heroku proxy header（例如 `X-Forwarded-Proto`）能被正確判斷。
   - ⬜ 補 request/integration spec：HTTP 會被 redirect，HTTPS 會通過。

2. `webmock-service-tests`
   - ⬜ 加入 `webmock` 測試依賴。
   - ⬜ 測試 `AuthenticateAccount` service 的 success / failure / service unavailable。
   - ⬜ 測試 `RegisterAccount` service 的 success / validation error / API error。
   - ⬜ 測試 `ListAccounts` service 的 admin listing response。
   - ⬜ 測試 system role update service 的 success / forbidden / API error。
   - ⬜ 在 test setup 禁止真實外部 HTTP request。

3. ✅ `basic-registration-workflow`（已存在，需本週複查）
   - 已完成：registration page 接收 `email`、`username`、`password`。
   - 已完成：controller 透過 `RegisterAccount` service object POST 到 API。
   - 已完成：registration 成功後可把 account data 寫入 App session。
   - 待複查：作業提醒此 workflow 尚未做 account detail verification，README/plan 需要明確保留這個風險說明。
   - 待複查：確認 error messages 與 redirect flow 在 API unavailable 時仍可讀。

4. `secure-messaging-library`
   - ⬜ 新增 secure messaging library。
   - ⬜ 從 environment variable `MSG_KEY` 讀取 secret key。
   - ⬜ 使用 NaCl `SimpleBox` 進行所有加密/解密。
   - ⬜ 設計 message format，至少包含 nonce 與 ciphertext。
   - ⬜ 解密失敗時回傳明確錯誤，不讓壞資料變成有效 session。
   - ⬜ 補 unit tests：round trip、不同 key 失敗、tampered message 失敗。

5. `secure-session-library`
   - ⬜ 新增 secure session library。
   - ⬜ 提供安全的 set/get/delete session variables helper。
   - ⬜ 所有 crypto 都只透過 secure messaging library，不在 controller 直接加密。
   - ⬜ 將 `current_account` 等 session value 改由 secure session library 存取。
   - ⬜ 補 tests：session value 寫入後不是 plaintext，讀取後可還原原始資料。

6. `session-pooling-and-redis`
   - ⬜ Development/test 使用 session pooling strategy。
   - ⬜ Production 使用 Redis 作為 distributed session store。
   - ⬜ 在 Heroku provision RedisCloud。
   - ⬜ 透過 production environment variables 指定 Redis connection URL。
   - ⬜ 確認 Redis 不可用時有可理解的錯誤或 fail-fast 行為。

7. `app-heroku-deployment`
   - ⬜ 建立 Heroku App dyno。
   - ⬜ 設定 `RACK_ENV=production`。
   - ⬜ 設定 `API_URL` 指向 deployed API。
   - ⬜ 設定 `SESSION_SECRET`。
   - ⬜ 設定 `MSG_KEY`。
   - ⬜ 設定 RedisCloud 相關 config vars。
   - ⬜ 確認 production logs 沒有輸出 plaintext password、session payload、message key。

8. `production-smoke-checks`
   - ⬜ 在 deployed App 測試 registration。
   - ⬜ 在 deployed App 測試 login/logout。
   - ⬜ 在 deployed App 測試 admin settings account listing。
   - ⬜ 在 deployed App 測試 admin role update。
   - ⬜ 確認 browser 使用 HTTPS，且 response 有 HSTS header。
   - ⬜ 確認 App 操作寫入 deployed API 的 production database。

## 依賴順序

- `webmock-service-tests` 可與 `app-https-hsts` 平行進行。
- `secure-messaging-library` -> `secure-session-library`
- `secure-session-library` -> `session-pooling-and-redis`
- `basic-registration-workflow` 複查 -> `production-smoke-checks`
- `app-heroku-deployment` 依賴 API 已先完成 deployed API URL。
- `session-pooling-and-redis` -> `app-heroku-deployment`

## 待組內決策

- `MSG_KEY` 的產生格式：是否使用 base64 encoded key，或直接使用 raw bytes encoded string。
- Secure session value 是否只加密 `current_account`，或所有 App session values 都統一加密。
- HTTPS/HSTS 是否只在 production 啟用，development/test 是否只用 spec 模擬。
- RedisCloud plan 使用哪個免費/課程允許方案。
- Registration 成功後是否自動登入，或 redirect login 讓使用者重新登入。

## 本週完成定義

- App production request 會導向 HTTPS，且所有 production response 都有 HSTS。
- App service tests 使用 WebMock，不需要連到真實 API。
- Registration form 仍可透過 service object 呼叫 API 建立帳號，並明確標記尚未驗證 account details 的風險。
- Session data 透過 secure messaging library 加密後存放。
- Development/test 使用 session pool，production 使用 RedisCloud distributed session store。
- Heroku App 可以連到 deployed API，使用者可在雲端完成建立/更新資源流程。
