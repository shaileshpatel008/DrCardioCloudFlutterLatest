# Dr. Cardio ECG Cloud — Panel API v2: install guide for the Laravel developer

**Project:** `cloudecg.drcardio.in` (Laravel 11, PHP 8.2, Sanctum)
**Goal:** add a JSON API at `/api/v2` so the new Flutter panel app (web, Android, iOS) can work with the existing system.
**Time needed:** about 30–60 minutes including testing.

## What this change is (and is not)

- It **adds** new files: 13 controllers, 2 middleware, 1 support class, 1 route file.
- It makes **3 small edits** to existing files (shown below, 6 lines in total).
- **No database changes.** The only table it uses that the web panel doesn't is
  `personal_access_tokens` (Sanctum). Its migration already exists in the project
  (`2024_03_31_053006_create_personal_access_tokens_table`).
- **Nothing existing changes behaviour.** The web panel, the existing mobile API
  (`routes/api.php`: login, upload-pdf, cardio-*) and all existing routes keep working exactly as now.
- Create / update / delete actions call the **existing web controllers**
  (`ClientController::store`, `PdfsController::pdfDiagnoseStatusChange`, `StaffController::store`, …),
  so validation, report PDF generation, FCM push and notifications are the same code as the web panel.
- Lists are new JSON queries that copy the web panel's role scoping (admin / OEM / client / cardiologist).
- Authentication is Sanctum **bearer tokens** (no cookies, no sessions). The login checks passwords the same
  way as the web panel (`Crypt::decryptString`) and allows the same roles (admin, sub_admin/OEM, client, cardiologist).

## Package contents

```
1_new_files/                 copy into the project root, same paths (nothing here overwrites an existing file)
  app/Http/Controllers/API/V2/   ApiController + 12 controllers + Concerns/
  app/Http/Middleware/ApiRole.php
  app/Http/Middleware/ForceJsonResponse.php
  app/Support/PanelUser.php
  routes/api_v2.php
2_edits_to_existing_files/
  existing-files.patch       the 3 edits as a git diff
  after/                     how the 3 files look after the edit (reference only; don't overwrite blindly)
3_testing_staging_only/
  api_v2_smoke_test.py       129 automated checks (creates and deletes data: staging only)
  PanelTestSeeder.php        fictional *@test.local accounts the smoke test needs (staging only)
API_REFERENCE.md             every endpoint, request and response format
HANDOVER.md                  this file
```

## Before you start

1. **Back up** the code and the database.
2. **Use a staging copy first if you have one** (a copy of the site + a copy of the DB). If not, the change is
   additive and easy to roll back (see the end), so it is reasonable to install on live directly.
3. Check Sanctum is installed (it is in `composer.json`):

   ```bash
   composer show laravel/sanctum
   ```

   If it says "not found", run `composer require laravel/sanctum:^4.0`.

## Step 1 — Copy the new files

Copy everything inside `1_new_files/` into the Laravel project root, keeping the paths. All of these files are new;
none of them exists in the current project.

## Step 2 — Make the 3 edits

If the server code is in git: `git apply 2_edits_to_existing_files/existing-files.patch`.
Otherwise make them by hand:

**a) `app/Models/User.php`** — add the Sanctum trait:

```php
use Laravel\Sanctum\HasApiTokens;          // add with the other use lines

class User extends Authenticatable
{
    use HasApiTokens, Notifiable, SoftDeletes;   // was: use Notifiable, SoftDeletes;
```

**b) `bootstrap/app.php`** — register two middleware aliases:

```php
use App\Http\Middleware\ApiRole;              // add at the top
use App\Http\Middleware\ForceJsonResponse;    // add at the top

        $middleware->alias([
            'checkRoles' => CheckRoles::class,
            'auth.admin' => AccessAdmin::class,
            'apitoken'   => APIToken::class,       // note the comma that was missing before
            'apiRole'    => ApiRole::class,        // new
            'forceJson'  => ForceJsonResponse::class, // new
        ]);
```

**c) `routes/api.php`** — add one line at the very end of the file:

```php
// Panel API v2 (Flutter web / Android / iOS panel app)
require __DIR__.'/api_v2.php';
```

## Step 3 — Run the artisan commands

```bash
php artisan migrate:status
```

Look for `create_personal_access_tokens_table`. If it already says **Ran**, skip the next command.
If it is the only **Pending** migration, run it. (If other migrations are pending too, check them first:
`migrate` runs all pending ones.)

```bash
php artisan migrate --force
```

Clear the cached config and routes so Laravel picks up the new routes:

```bash
php artisan optimize:clear
```

If the server normally runs with cached config/routes, cache them again:

```bash
php artisan optimize
```

Check the new routes are registered — this should list **54 routes**:

```bash
php artisan route:list --path=api/v2
```

**Cache store:** the forgot-password rate limit uses the cache. In `.env`, `CACHE_STORE` must be `file`
or `redis`. `database` only works if a `cache` table exists (the project has no migration for it).

> No SSH? Use the hosting panel's Terminal (cPanel → Terminal) for the commands above.

## Step 4 — Check it works

Sign in with a real Super Admin account (replace the email and password):

```bash
curl -s -X POST https://cloudecg.drcardio.in/api/v2/auth/login -H "Accept: application/json" -H "Content-Type: application/json" -d '{"email":"ADMIN_EMAIL","password":"ADMIN_PASSWORD"}'
```

Expected: `{"status":"success","data":{"token":"1|…","user":{…,"role":"admin","menu":[…]}}}`.

Then use that token:

```bash
curl -s https://cloudecg.drcardio.in/api/v2/dashboard -H "Accept: application/json" -H "Authorization: Bearer PASTE_TOKEN_HERE"
```

Expected: `{"status":"success","data":{"tiles":[…],"counts":{…},…}}`.

Common problems:

| You see | Cause / fix |
|---|---|
| `The route api/v2/auth/login could not be found` | Step 2c line missing, or old route cache: run `php artisan optimize:clear` |
| `Target class [apiRole] does not exist` | Step 2b aliases missing |
| `Call to undefined method …User::createToken()` | Step 2a trait missing |
| `Table 'personal_access_tokens' doesn't exist` | Run the migration (Step 3) |
| 500 error mentioning `cache` table | `CACHE_STORE=file` in `.env`, then `php artisan optimize:clear` |
| Login returns "The credentials do not match." | Wrong email or password (normal) |
| Login returns "This account cannot sign in to the panel…" | Staff (technician) account: refused on purpose, same as the web panel |

Details of any 500 error are in `storage/logs/laravel.log`.

## Step 5 (optional, staging only) — Full automated test

Only on a **staging copy**, never on live: it creates and deletes clients, staff, devices and reports.

```bash
cp 3_testing_staging_only/PanelTestSeeder.php database/seeders/
```

```bash
php artisan db:seed --class=PanelTestSeeder --force
```

```bash
BASE=https://YOUR-STAGING-DOMAIN/api/v2 python3 3_testing_staging_only/api_v2_smoke_test.py
```

Expected last line: `129/129 passed`.

## Step 6 (when ready) — Host the Flutter web app

The Flutter developer builds the web app (`flutter build web --release`) and sends you the `build/web` folder.
Host it on its own sub-domain, e.g. `panel.drcardio.in` (a separate folder/vhost, **not** inside Laravel's `public/`).

The app uses clean URLs (`/clients`, `/ecg/123`), so the server must send `index.html` for unknown paths.

Apache — `.htaccess` in the web app folder:

```apache
RewriteEngine On
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^ index.html [L]
```

nginx:

```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

Enable HTTPS on the sub-domain. **CORS:** nothing to do. The project has no `config/cors.php`, so Laravel 11's
default applies (`api/*` allowed from any origin), and the app sends bearer tokens, not cookies. If someone has
published `config/cors.php` on the server, make sure `paths` includes `api/*`.

## How to undo it

Remove the `require __DIR__.'/api_v2.php';` line from `routes/api.php` and run `php artisan optimize:clear`.
The API is then gone. The other two edits (trait, aliases) are harmless and can stay or be reverted.
To also sign out every app user, empty the `personal_access_tokens` table.

## Please send back to the Flutter developer

1. "Installed" + the output count of `php artisan route:list --path=api/v2` (should be 54).
2. Whether the login `curl` in Step 4 returned `"status":"success"` (do **not** send the token).
3. The staging URL, if you installed on staging first.

## Issues found in the existing code (for your review)

Found while reading the current Laravel code. Items 1–4 are already handled correctly **in the new API only**;
the web panel still behaves the old way.

1. **Download ECG leaks data across clients.** With "All hospitals", the web export has no owner filter, so an
   OEM user or a client exporting "All" receives every client's ECGs.
2. **Missing ownership checks on some web writes.** The client and device `update` actions, staff
   `update`/`delete`, and the diagnose action don't check that the record belongs to the signed-in OEM user /
   client / cardiologist (only the edit *pages* check).
3. **The OEM user Delete button calls the wrong URL** (`/client/{id}/delete`) and fails.
4. **The ECG list can show duplicate rows** when a client has more than one `client_cardiologist` row (LEFT JOIN).
5. **Passwords use reversible encryption** (`Crypt::encryptString`) and the web View pages / staff edit dialog
   show them in plain text. Moving to `Hash::make` needs the web login and the mobile login changed together.
6. **`composer.lock` is out of sync with `composer.json`** (e.g. AdminLTE, Firebase packages), so
   `composer install` fails on a clean machine. Run `composer update` once in a controlled environment and commit the lock.
7. **Dashboard and sidebar totals differ** for Super Admin: the dashboard and ECG list count only admin-owned
   clients (`parent_user_id = 0`), the sidebar counts all. The API follows the dashboard.

The endpoint list and response formats are in `API_REFERENCE.md`.
