# Dr. Cardio ECG Cloud — Flutter panel (web · Android · iOS)

Flutter + GetX rebuild of the Laravel admin panel at `cloudecg.drcardio.in`,
with the redesigned UI. One codebase runs as a web app, an Android app and an
iOS app. It talks to the **Panel API v2** in `../laravel_api_v2` (install that
on the server first).

## Roles and what each one sees

The server returns each user's role and allowed sections (`menu`), and every
route is guarded, so each role gets exactly the web panel's sections:

| Section | Super Admin | OEM user | Client | Cardiologist |
|---|---|---|---|---|
| Dashboard (role-specific tiles + insights) | ✓ | ✓ | ✓ | ✓ |
| ECG Records (+ detail) | all admin-owned | own clients | own | assigned to them |
| Delete / re-assign / send for report | ✓ | ✓ | | |
| Diagnose — write & publish report | | | | ✓ |
| Download ECG (PDF zip / CSV zip) | ✓ | ✓ | ✓ | |
| Export ECG Counts (monthly CSV) | | | | ✓ |
| Clients (+ add / edit / detail / staff) | ✓ | ✓ | | |
| Staff (all) | ✓ | | | |
| My Staff (+ cardiologist per technician) | | | ✓ | |
| Cardiologists | ✓ | ✓ | with multi-hospital access | |
| Devices | ✓ | ✓ | | |
| OEM Users | ✓ | | | |
| Notifications (60 s refresh, sound) | ✓ | ✓ | ✓ | ✓ |
| My Profile (role-specific fields) | ✓ | ✓ | ✓ | ✓ (logo, signature, footer) |

Staff (technicians) keep using the Dr. Cardio mobile recording app; the panel
refuses their sign-in, exactly like the web.

## Run

```bash
flutter pub get
```

Web (Chrome):

```bash
flutter run -d chrome
```

Android / iOS:

```bash
flutter run
```

The API base URL defaults to `https://cloudecg.drcardio.in/api/v2`. Point it
at a staging or local server with `--dart-define`:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v2
```

## Build

```bash
flutter build web --release
```

Upload `build/web/` to any static host (it can be a sub-domain such as
`panel.drcardio.in`). The app uses clean URLs (`/clients`, `/ecg/123`), so the
host must serve `index.html` for unknown paths — e.g. nginx
`try_files $uri $uri/ /index.html;`, or on Apache a `.htaccess` rewrite to
`index.html`.

```bash
flutter build apk --release
```

```bash
flutter build ipa --release
```

## Demo build (clickable prototype, no server needed)

For client presentations, the same app can run on built-in sample data:

```bash
flutter build apk --release --dart-define=DEMO_MODE=true
```

```bash
flutter build web --release --dart-define=DEMO_MODE=true
```

- **No request leaves the device.** `lib/core/demo/` answers every Panel API v2
  call (same paths, filters, paging and JSON shapes) from
  `assets/demo/demo_data.json`: 8 hospitals, 5 cardiologists, an OEM partner,
  staff, devices and 162 ECGs over 30 days, all fictional (`*@example.com`).
- **The sign-in screen offers one-tap demo roles** (Super Admin, OEM partner,
  Hospital / clinic, Cardiologist); any password works. A "DEMO" badge shows
  in the top bar.
- **Everything is clickable, including saving.** Publish a report, add
  clients, staff, devices, cardiologists and OEM users, re-assign or delete
  ECGs, and export (real zip of ECG PDFs / CSVs, counts CSV). Changes live in
  memory and reset when the app restarts. A report published as the
  cardiologist shows up for the admin and the hospital in the same session.
- **ECG recordings and reports are drawn on the device:** a 12-lead sheet, plus
  a report page built from the cardiologist's values. The ECG opens full
  screen in landscape on phones.
- **The demo APK installs next to the live app** as "Dr. Cardio Demo"
  (`com.drcardio.cloudpanel.demo`).
- **The demo web build uses `/#/` URLs,** so it can be uploaded to any static
  host as-is.

Without `DEMO_MODE` none of this is active and the app talks to the real API.
`tool/demo_data/` regenerates the sample data from a local copy of the backend.

## Folder structure

Same layout as the mobile app (`lib/{core,data,modules,routes,theme}`, one
GetX module per screen with `bindings/ controllers/ views/ widgets/`):

```
lib/
  core/
    base/          PagedListController (paging, search, sort, stale-response guard)
    constants/     API endpoints, date presets
    network/       Dio client (bearer token, 401 → sign-in), ApiException
    services/      AuthService (session), StorageService, file download, alert sound
    utils/         formatters, validators, responsive breakpoints, HTML⇄text, links
    widgets/       UI kit, tables + pagination, forms, dialogs, PDF preview, ECG trace
  data/
    models/        user, ECG record + filters, clients/staff/devices/…, dashboard
    repositories/  auth, ECG, clients, staff, cardiologists, devices, OEM, lookups, exports, profile
  modules/         login, dashboard, ecg_records, ecg_detail, diagnose, download_ecg,
                   export_counts, clients, client_form, client_detail, staff,
                   cardiologists, devices, oem_users, profile, notifications, shell
  routes/          AppRoutes, AppPages, AuthGuard / GuestGuard
  theme/           colours, text styles, Material theme
```

## Platform behaviour

| | Web | Android / iOS |
|---|---|---|
| Layout | sidebar ≥1100 px, icon rail 760–1100, drawer + cards on phones | same responsive rules |
| PDFs | embedded viewer on record & diagnose screens | opens the system PDF viewer |
| Exports (zip / csv) | normal browser download | saved, then the share sheet opens (Files, Drive, WhatsApp…) |
| New-ECG alert | chime (after the first click on the page — browser rule) | system alert sound + haptic |

Material note: GetX 4.x is built on `package:flutter/material.dart`, which
Flutter ≥ 3.47 marks deprecated in favour of `package:material_ui`. The two
cannot be mixed, so this app (like the mobile app) uses the SDK library and
`analysis_options.yaml` silences that one deprecation. For the same reason
`google_fonts` is pinned to 6.x (7+ moved to `material_ui`).

## Verified in this session

- `flutter analyze` — no issues; `flutter test` — passes (incl. the demo API tests).
- Web release build driven in Chromium against a local copy of the Laravel
  backend with the API patch, signing in through the real login form as each
  of the four roles: every screen opened at 1440 px and 390 px with no console
  errors; route guards redirect roles away from sections they don't have.
- Write flows through the UI, each verified via the API: cardiologist
  publishes a report (status, ECG status, measurements, QT/QTc, advice
  bullets); admin creates a client with a device; duplicate email shows the
  server error under the field; admin adds a device; export downloads a zip;
  client adds a staff member.
- `flutter build apk --release` succeeds (app id `com.drcardio.cloudpanel`).
  It is signed with Flutter's default debug key — add your own keystore in
  `android/app/build.gradle.kts` before publishing to the Play Store.
- Not run here: on a physical Android or iOS device, an iOS build (needs a
  Mac with Xcode), and against the production server.
