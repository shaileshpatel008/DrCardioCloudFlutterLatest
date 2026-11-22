# Panel API v2 — Laravel patch for the Flutter ECG Cloud panel

The existing Laravel panel renders HTML pages (Blade + DataTables), so a
Flutter app cannot use it directly. This patch adds a **JSON API** under
`/api/v2` that the Flutter app (`../cloud_panel`) uses on web, Android and iOS.

It is **additive**: the web panel and the existing mobile API (`routes/api.php`
login / upload-pdf / cardio-* endpoints) keep working unchanged.

## How it stays faithful to the current panel

- **Create / update / delete** run through the *existing* web controller
  actions (`ClientController::store`, `PdfsController::pdfDiagnoseStatusChange`,
  `StaffController::store`, …). Validation, default-staff creation, device
  rename-on-delete, report PDF generation + merge, FCM push, notifications —
  all identical, because it is the same code.
- **Dashboard counters** come straight from `HomeController::index()`.
- **Lists** are clean JSON queries that copy the web scoping rules
  (admin → `parent_user_id = 0`, OEM → their own, client → own, cardiologist →
  assigned), with whitelisted sorting and server-side paging.
- **Login** uses the same rules as the web: only admin / sub_admin (OEM) /
  client / cardiologist may sign in, password checked with `Crypt::decryptString`.

## Install (10 minutes)

> Step-by-step guide with checks, troubleshooting and rollback: **`HANDOVER.md`**.

1. Copy the new files into the Laravel project (same paths):

   ```
   app/Http/Controllers/API/V2/            (whole folder)
   app/Http/Middleware/ApiRole.php
   app/Http/Middleware/ForceJsonResponse.php
   app/Support/PanelUser.php
   routes/api_v2.php
   ```

2. Apply the three small edits to existing files — either copy
   `app/Models/User.php`, `bootstrap/app.php`, `routes/api.php` from this
   folder, or apply the diff:

   ```bash
   git apply laravel_api_v2/existing-files.patch
   ```

   | File | Change |
   |---|---|
   | `app/Models/User.php` | add `use Laravel\Sanctum\HasApiTokens;` to the model |
   | `bootstrap/app.php` | register `apiRole` and `forceJson` middleware aliases |
   | `routes/api.php` | `require __DIR__.'/api_v2.php';` at the end |

3. Make sure the Sanctum tokens table exists (the project already has the
   migration `2024_03_31_053006_create_personal_access_tokens_table`):

   ```bash
   php artisan migrate --force
   ```

4. Clear caches:

   ```bash
   php artisan optimize:clear
   ```

5. Check it:

   ```bash
   php artisan route:list --path=api/v2
   ```

   should list 54 routes.

Nothing else is required. CORS: Laravel 11's built-in defaults already allow
`api/*` from any origin, and the app uses bearer tokens (no cookies), so the
Flutter web build can be hosted on any domain.

> Rate limiting (`throttle`) uses the cache store. Keep `CACHE_STORE=file`
> (or redis) in `.env` — the project has no `cache` table migration, so the
> `database` cache store from `.env.example` would fail.

## Testing

`api_v2_smoke_test.py` runs 129 checks across all four roles (lists, scoping,
every create/update/delete, re-assign, report publish with PDF merge, exports,
notifications, profile, permission boundaries). **Run it only against a
local or staging copy** — it creates and deletes data and uses `*@test.local`
accounts that must exist:

```bash
BASE=http://127.0.0.1:8000/api/v2 python3 api_v2_smoke_test.py
```

Result in this session against a local copy of the project (MariaDB): **129/129 passed**.

## Endpoints

All responses are `{"status":"success","data":…,"message"?:…}` or
`{"status":"error","message":…,"errors"?:{field:[…]}}`. Lists add
`"meta":{"page","per_page","total","last_page"}` and accept
`?page&per_page(10|25|50|100)&search&sort&dir(asc|desc)`.
Send `Accept: application/json` and `Authorization: Bearer <token>`.

| Method & path | Roles | Notes |
|---|---|---|
| `POST auth/login` | public | `{email,password,device_name?}` → `{token,user}`; user has `role`, `menu`, profile |
| `POST auth/forgot-password` | public | `{email}` — same reset mail as the web |
| `GET auth/me` · `POST auth/logout` | all | logout revokes the token |
| `GET dashboard` | all | `tiles` (per role, as the web), `counts`, `insights` (14-day volume, month status mix, avg TAT), `recent` |
| `GET ecg-records` | all | role-scoped; filters `hospital_id, staff_id, device_id, cardiologist_id, status, ecg_status, date_filter, from_date, to_date`; sort `date,staff,hospital,device,status,file` |
| `GET ecg-records/summary` | all | counts per report status (tabs) |
| `GET ecg-records/{id}` | all | detail incl. measurements, report HTML, PDF/CSV URLs, allowed `actions` |
| `DELETE ecg-records/{id}` | admin, OEM | |
| `POST ecg-records/{id}/reassign` | admin, OEM | `{cardiologist_id}` |
| `POST ecg-records/{id}/assign` | admin, OEM | send a "no credit" ECG to the client's cardiologist |
| `GET/POST ecg-records/{id}/diagnose` | cardiologist | form data + templates / `{action: draft\|publish, ecg_status, cardiologist_report, hr, r, rr, pr, qrs, qt, qtc, qt_by_qtc}` |
| `GET/POST/PUT/DELETE clients[/{userId}]` | admin, OEM | all web form fields; `devices[]` on create |
| `GET clients/{userId}/staff` | admin, OEM | |
| `GET admin-staffs` | admin | |
| `GET staffs` | client | own staff (with cardiologist) |
| `POST staff` · `GET/PUT/DELETE staff/{id}` | admin, OEM, client | client may set `cardiologist_id` |
| `GET/POST/PUT/DELETE cardiologists[/{userId}]` | admin, OEM, client* | *client only with multi-hospital access (as the web) |
| `GET/POST/PUT/DELETE devices[/{id}]` | admin, OEM | `{hospital_id, intrument_id}` |
| `GET/POST/PUT/DELETE oem-users[/{id}]` | admin | |
| `GET exports/ecg/count` · `POST exports/ecg` | admin, OEM, client | `{type: pdf\|csv, …filters}` → zip download |
| `POST exports/ecg-counts` | cardiologist | `{month: 01-12, year}` → CSV |
| `GET notifications` · `POST notifications/{id}/read` · `POST notifications/read-all` | all | |
| `GET/POST profile` · `DELETE profile/logo` · `DELETE profile/signature` | all / cardiologist | multipart for logo & signature |
| `GET lookups/hospitals\|cardiologists\|staffs?hospital_id\|devices?hospital_id` | all | dropdown sources, scoped |

## Things found in the existing code (please review)

Fixed **in the new API only** (the web panel still behaves the old way):

1. **Download ECG leaks data across clients.** With "All hospitals", the web
   export applies no owner filter, so an OEM user or a client exporting "All"
   gets every client's ECGs. The API scopes OEM users to their own clients and
   clients to their own records.
2. **Missing ownership checks on some writes.** In the web panel the client
   and device `update` actions, the staff `update`/`delete` actions and the
   diagnose action don't check that the record belongs to the signed-in OEM
   user / client / cardiologist (only the edit *pages* check). The API checks
   ownership before every write.
3. **OEM user Delete button calls the wrong URL** (`/client/{id}/delete`) and
   fails. The API calls `OemController::delete`.
4. **ECG list can duplicate rows** if a client has more than one
   `client_cardiologist` row (LEFT JOIN). The API uses a sub-select.

Still in the system (need a backend decision, not changed):

5. **Passwords are stored with reversible encryption** (`Crypt::encryptString`),
   and the web View pages / staff edit dialog show them in plain text. The
   new app never displays passwords. Moving to one-way hashing (`Hash::make`)
   needs the mobile login + web login changed together — worth planning.
6. **`composer.lock` is out of sync with `composer.json`** (e.g. it locks
   AdminLTE 3.11 while `composer.json` requires ^3.12, and the Firebase
   packages are missing from the lock). `composer install` fails on a clean
   machine; run `composer update` once in a controlled environment and commit
   the new lock.
7. **Dashboard vs sidebar totals differ** because the Super Admin dashboard
   (and ECG list) only count admin-owned clients (`parent_user_id = 0`) while
   the sidebar counts everything. The API matches the dashboard/list.
