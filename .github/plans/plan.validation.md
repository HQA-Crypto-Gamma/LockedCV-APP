# LockedCV-APP Form Validation 與 API Model Parsing 實作計畫

## 問題與目標

- 本週 App 目標是集中處理 web form input validation，避免 controller 直接整理/判斷 raw `routing.params`。
- App 需要使用 `dry-validation` 建立 form objects，放在 `app/forms/`。
- 每個有 user input 的 view 都應有對應 form schema。
- Controller 應直接把 `routing.params` 傳給 form object，確認 validation success 後，把 validated form object/value 傳給 service。
- Form objects 需要回傳可被 App 顯示、也可被 API 重用概念的 error messages。
- App 需要擴充 `app/models/`：所有 API response hash/array parsing 應集中在 App models，不應散落在 controllers/services/views。
- App models 不做重要 domain decision；重要邏輯仍屬於 API models/policies。
- App 應使用 API 回傳的 policy summaries/capabilities 來決定是否顯示 links/buttons/resources，不在 App 自己推論 authorization。

## 現況分析（2026-05-31）

- 專案：`LockedCV-APP`
- 目前已有：
  - `Account` model：包住 authenticated account/session data。
  - `CurrentSession` model：集中讀寫 secure session account/auth token。
  - `ApiClient`：集中 API URL、JSON parsing、Bearer token request。
  - Services：authenticate/register/verify registration/find/update/change password/list/delete/list attachments/upload attachment 等。
  - `dry-validation` dependency。
  - `app/forms/` 與 shared `Form` helpers。
  - Auth/registration/account/settings/attachment upload form contracts。
  - Controllers 已在打 API 前用 form objects 驗證 login、registration、profile update、password update、settings role assignment、attachment upload。
  - Validation failure specs 確認 invalid input 不會打 API。
  - `ChangePassword` 和 `UpdateAccount` services 已移除重複的 form-shape validation，改由 controller/form 負責；services 保留 API 400/error mapping。
  - `Attachment` app model 已解析 API attachment envelope 與 policy summary，並提供 `can_delete?`。
  - Home view 已根據 `attachment.can_delete?` 顯示/隱藏 delete action。
- 目前尚未有：
  - 統一 field-level form error rendering convention；目前多數 route 先使用 flash 或頁面訊息。
  - Account list/capability parser models。
  - 完整 policy summary UI pattern；目前 attachment delete action 已接入，其他 policy 欄位仍待補。

## API Policy Integration Notes

- API `plan.policies.md` 會讓 resource responses 回傳 `policy`/`policies`，current account response 回傳 `capabilities`。
- App 不自行推論 authorization，只根據 API 回傳的 summary 控制 UI 顯示；API 仍是安全邊界。
- Attachment 權限語意暫定：
  - `can_view`：可看原始 PDF / raw sensitive data。
  - `can_view_masked`：可看遮罩版 PDF / masked output。
  - `can_delete`：可刪除該 attachment。
  - `can_upload` 或 account capability：可上傳新的 attachment。
- APP model parsing 需要把 policy summary 包成 readable interface。現況：`Attachment#can_delete?` 已接上；後續可補 `can_view?`、`can_view_masked?`、`role` 等 predicates，views 不直接讀 raw API hash。

## 參考方向

- Professor repo `tyto2026-app` 可參考：
  - `app/forms/form_base.rb`
  - `app/forms/auth.rb`
  - `app/forms/new_course.rb`
  - `app/models/course.rb`
- 可採相同概念：
  - `Form` module 裡放共用 regex/constants/error helpers。
  - 每個 form contract 使用 `Dry::Validation.Contract`。
  - Form helper 回傳 `validation_errors` 與 sanitized `message_values`。
  - API parser model 使用 `.from_api(envelope)` factory，集中處理 API envelopes 與 policies。
  - 可用 model predicate 或 `OpenStruct` 包裝 policy summary，讓 views 使用 `attachment.can_delete?` 或 `attachment.policies.can_delete` 這類 readable interface。

## 實作策略（分階段）

1. **Dependency and form base**：加入 `dry-validation`，建立 `app/forms/form_base.rb` 與 loader。
2. **Form inventory**：盤點所有 user input views/routes，建立表單清單與欄位契約。
3. **Auth and registration forms**：先處理 login、registration start、registration verify/password flow。
4. **Account forms**：處理 profile update 與 password change。
5. **Admin/settings forms**：處理 system role assignment、account delete confirmation（若有 confirmation input）。
6. **Attachment forms**：處理 upload/delete/masked export/sensitive data forms。
7. **Controller adoption**：controller 只做 form validation -> service call -> render/redirect，不直接 parse/validate params。
8. **API parser models**：建立 `Attachment`、`AttachmentList`、`AccountList` 或類似 parser models，把 API hash/array parsing 從 services/controllers/views 移出。
9. **Policy summary UI**：App models 包住 API 回傳的 `policies`/`capabilities`，views 根據 policy summary 顯示 links/buttons/actions。
10. **Tests and docs**：補 form unit specs、service/controller integration specs、README/copilot/local docs。

## Todo 清單

1. ✅ `dry-validation-setup`
   - 在 Gemfile 加入 `dry-validation`。
   - 建立 `app/forms/`。
   - 建立 `app/forms/form_base.rb`。
   - 更新 `require_app` / loader，讓 forms 可被 controllers 使用。
   - 建立 helper：
     - `validation_errors(result)`
     - `message_values(result)`
     - common regex/constants，例如 username/email/password/birthday。

2. `form-inventory`
   - 盤點目前 user input routes：
     - `POST /auth/login`
     - `POST /auth/register`
     - `POST /auth/register/verify` 或現有 equivalent。
     - `POST /account/:username`
     - `POST /account/:username/password`
     - `POST /settings`
     - `POST /settings/accounts/:account_id/delete`
     - `POST /attachments/upload`
     - `POST /attachments/:attachment_id/delete`
   - 每個 route 對應一個 form contract 或明確記錄不需要 schema 的原因。

3. ✅ `auth-registration-forms`
   - `LoginCredentials`：
     - `username` required string。
     - `password` required string。
   - `RegistrationStart`：
     - `username` required string，格式限制。
     - `email` required string，基本 email shape。
   - `RegistrationPassword`：
     - `password` required。
     - `password_confirmation` required。
     - custom rule：password confirmation 必須一致。
   - Controller 直接傳 `routing.params` 給 form object。
   - Service 只接 validated values，不直接接 raw params。

4. ✅ `account-profile-password-forms`
   - `AccountProfile`：
     - `email` required。
     - `phone_number` optional/required 依目前 UI。
     - `first_name`、`last_name`、`address`、`identification_numbers` optional。
     - `birthday` 使用 `YYYY-MM-DD` validation；`UpdateAccount` 已改由 form 負責，`RegisterAccount` 仍暫留既有 `BirthdayValidator` 防線。
   - `ChangePassword`：
     - `current_password` required。
     - `password` required。
     - `password_confirmation` required。
     - custom rule：new password confirmation 必須一致。
   - 更新 account controller：validation failure 時 re-render form 並帶 errors/values。

5. ✅ `settings-forms`
   - `AssignSystemRole`：
     - `username` required。
     - `role` required，值必須在 App 已知 system roles 或 API documented roles 中。
   - `DeleteAccount`：
     - 若 UI 有 confirmation input，建立 confirmation rule。
     - 如果只是 route target id，需確認 target id 不是 requesting user id 的 UI guard 只能當 UX；API policy 仍是安全邊界。

6. ✅ `attachment-forms`
   - `UploadAttachment`：
     - `cv` required。
     - filename extension `.pdf` 的 App-side friendly validation。
     - 檔案 magic/header 仍由 API final validation。
   - `DeleteAttachment`：
     - route param `attachment_id` required。
   - 後續若 UI 接 sensitive data/masked export：
     - `SensitiveData` form schema。
     - `ExportMaskedAttachment` form schema。

7. ✅ `controller-form-adoption`
   - Controllers 不再直接用 `routing.params['field'].to_s.strip` 組 payload。
   - Pattern：

     ```ruby
     form = Form::AccountProfile.call(routing.params)
     return render_form_errors(form) unless form.success?

     UpdateAccount.new(App.config, current_account: @current_account).call(
       account_data: form.values.to_h
     )
     ```

   - Validation failure 保留 user input 並顯示 field-level errors。
   - API/service failures 仍走既有 flash 或 error rendering。

8. `api-parser-models`
   - 建立或補強 App-side parser models：
     - `Account`
     - `AccountList`
     - ✅ `Attachment`
     - `AttachmentList`
     - `PolicySummary` 或使用 `OpenStruct` 包裝 policies。
   - ✅ `ListAttachments` 回傳 `Attachment` App model objects，不直接回 raw API hash。
   - Controllers/views 不再知道 API envelope 細節，例如 `data -> attributes`。目前 attachment list 已完成，account/settings 仍待補。
   - App models 只做 parsing/representation，不做 authorization decision 或 domain mutation。

9. `policy-summary-ui`
   - 配合 API `plan.policies.md`，App models 讀取 API response 的 `policies` / `capabilities`。
   - Views 根據 policy summary 顯示 actions：
     - `account.capabilities.can_list_accounts`
     - ✅ `attachment.can_delete?`
     - `attachment.policies.can_view`
     - `attachment.policies.can_view_masked`
     - `attachment.policies.can_export_masked_pdf`
   - UI hide/show 只當 UX；API policy 仍是安全邊界。
   - 目前 API attachment index 已回傳 policy summary；App 已接 `can_delete`，其他欄位 deferred。

10. `validation-tests-and-docs`
   - Form unit specs：happy path、missing fields、invalid format、cross-field mismatch。
   - Controller specs：invalid form 不呼叫 API service，會 re-render 並顯示 errors。
   - Service specs：service 只處理 validated payload，不再負責 form shape validation。`ChangePassword`、`UpdateAccount` 已採用此 pattern；registration/upload/auth services 後續再評估。
   - 更新 README、`.github/copilot-instructions.md`、`local.md`。

## 依賴順序

- `dry-validation-setup` -> all form tasks。
- `form-inventory` -> `auth-registration-forms` / `account-profile-password-forms` / `settings-forms` / `attachment-forms`。
- `auth-registration-forms` -> registration controller cleanup。
- `account-profile-password-forms` -> profile/password controller cleanup。
- `api-parser-models` 可與 forms 平行，但 service return shape change 會影響 controller/views/tests。
- API `plan.policies.md` 的 policy summary response -> `policy-summary-ui`。

## 待組內決策

- App validation 是否只做 UX-friendly checks，API 也另做 authoritative validation；本週說明 bonus 可考慮移到 API。
- Password strength rule 要只做 presence/confirmation，還是加入 entropy/length/character-class。
- Username/email/birthday/phone 格式要採課程 demo 最小規則，或更嚴格規則。
- Form object naming：`Form::LoginCredentials`、`Forms::LoginCredentials`、或 class-based `LoginForm`。
- Services 回傳 raw hash 的 migration strategy：一次全改成 models，或先從 attachments/account list 開始。
- Policy summary 欄位在 API contract 中最終命名為 `policies`、`policy`、或 `capabilities`。

## 本週完成定義

- App 有 `app/forms/` 與 `dry-validation` setup。
- 所有目前有 user input 的 views/routes 都有對應 form object 或明確 deferred reason。
- Controllers 直接把 `routing.params` 傳給 form object；success 後只把 validated values 傳給 services。
- Validation errors 能回到 views 顯示。
- API response parsing 集中到 App models，不散落在 controllers/services/views。
- App models 不做重要 authorization/domain decision。
- 當 API 回傳 policy summaries/capabilities 時，App views 能以 summary 決定 links/buttons/actions 的顯示。
