# Dr. Cardio ECG — Flutter/GetX rebuild

A from-scratch Flutter port of `drcardiocloudsp` (the production Android app), built to the
architecture and stack the client asked for — **Flutter + GetX**, Android **and** iOS —
plus a redesigned UI, a redesigned PDF report, and dynamic sync with the real backend.

This is a **working, substantial rebuild**, not a toy scaffold: it talks to the real
`cloudecg.drcardio.in` API with the real request contract read out of the Android source,
runs the same Bluetooth protocol and signal-processing pipeline as the production app, and
covers all thirteen screens agreed with the client (see the design canvas shared earlier in
this conversation). It has **not** been run against real hardware or a real Android/iOS
build — see [What's verified](#whats-verified-in-this-session) — so budget for a hardware/
device pass before shipping.

## Why a rebuild, not a literal port

The client's brief was explicit: modern GetX architecture (not a straight Java→Dart
translation), a new look using the real brand (not the old dated layout), and a fixed PDF
report (the original's was flagged as misaligned/outdated). That means this isn't a
mechanical 1:1 port of every Activity — it's a rebuild of the same *functionality*, on a
different architecture and a redesigned UI, informed by reading the actual Android source
so the protocol, algorithms and API contract are faithful even where the code structure
isn't.

## What's faithfully ported from the Android app

| Original | This port | Notes |
|---|---|---|
| `appbluetoothmodule` (`AppBluetoothHelper`, `AppBluetoothConnectionThread`, `AppDeviceConnectedThread`) | `lib/core/services/bluetooth/` | Same SPP UUID, same `SORa`/`SORb`/`EOR` framing, same status/data byte lengths, same ACK/ERR throttling, same device-name filter (`Dr.Cardio/`). Built on `flutter_bluetooth_serial` for classic SPP (Android) and `flutter_reactive_ble` for BLE (iOS + Android alt path — **see the BLE caveat below**). |
| `SupportClass/ecgFilter.java` | `lib/core/services/ecg/ecg_filter.dart` + `fir_coefficients.dart` | All 5 order-200 FIR coefficient banks extracted programmatically from the Java source (not retyped) plus the high-pass IIR filter, same math. |
| `SupportClass/parseData.java` | `lib/core/services/ecg/parse_data.dart` | 2-byte/3-byte channel decoding, aux-lead derivation, and this repo's own later fix for multi-sample-per-payload parsing (`offset`), plus lead-off status decoding. |
| `Model/ecgData.java` | `lib/core/services/ecg/ecg_data.dart` | Buffers, lead order/naming, DC-shift baseline. |
| `SupportClass/DataHandlerThread.java` | `lib/core/services/ecg/ecg_engine.dart` | Same baseline→DC-correct→FIR→HPF→down-sample pipeline and order of operations, **including this repo's own bug fixes** (see below). |
| `SignInActivity` (`api/login`) | `lib/data/datasources/remote/auth_remote_datasource.dart` | Same form fields (`email`, `password`, `device_info`, `device_type`, `device_token`), same `{status, success_data / error_data}` response shape. |
| `MainActivity.uploadPDF()` (`api/upload-pdf`) | `lib/data/datasources/remote/ecg_remote_datasource.dart` | Same multipart fields (`device_id`, `latitude`, `longitude`, `device_info`, `patient_info`, `address`, `hr`/`r`/`rr`/`pr`/`qrs`/`qt`/`qtc`/`qt_by_qtc`, `have_to_assign_cardiologist`) and file parts (`document_path`, `csv_file`), same `Authorization: Bearer <token>` header. |
| `callGetLatestTokenApi()` (`api/get-token`) | `AuthRepository.refreshToken()` | Refreshes the token and reads the `report_limit`/`report_limit_enabled` plan quota. |
| `walkthroughscreen.IntroductionActivity` | `lib/modules/onboarding/` | Same 3 cards, same copy, same illustrations (`introduction1/2/3.png`, bundled as-is), shown once after install — this **is** the in-app user guide requested. |
| `act_menu_new.xml`'s real bottom nav (New ECG / Reports / Help / Settings) | `lib/modules/home/views/home_view.dart` | Not a generic "Home" tab — matches the actual 4-tab set. |
| `MyAccountsActivity` menu (Profile / Load Data / Offline Data / Settings / Help / Feedback / Rate / Share / Sign out) | `lib/modules/my_account/` | Same items, same header artwork (`mainlogo.png`/`header_pattern.png`, the app's real red header graphic — not redrawn). |
| Brand identity | `lib/theme/app_colors.dart`, `assets/images/logo_*.png` | Real primary red `#C53827` from `colors.xml`, and the actual `ic_app_logo.png`/`whitelogo.png`/`mainlogo.png` assets — not an invented palette or logo. |
| ECG monitor look | `lib/modules/live_ecg/widgets/ecg_lead_chart.dart` | Black background, yellow trace — matches `chart.setBackgroundColor(Color.BLACK)` / `set.setColor(Color.YELLOW)` exactly, per explicit instruction to keep this the same. |
| Lead-off / electrode status | `EcgData.leadStatus`, shown as a banner on the live ECG screen | This repo's newer `DataHandlerThread` added a lead-status Snackbar the app didn't originally have; ported here as an on-screen warning banner during recording. |

Two bugs this repo's own later Java commits had already found and fixed are kept fixed here
(ported from the *fixed* version, not the older one):
- The elapsed-seconds tick used `x % sampleRatePerSec == 500`, which can never be true —
  fixed to `== 0`.
- The original mutated MPAndroidChart's `LineData` directly from the background thread,
  which caused a real `NegativeArraySizeException` under load. Flutter's model sidesteps
  this structurally: `EcgEngine` never touches a widget, only a plain `List<double>` +
  a `ValueNotifier` tick, so there's no cross-thread chart mutation to race in the first
  place — no queue-and-drain workaround needed.

## What's new / redesigned (as asked)

- **Visual design** — new UI across all 13 screens, using the real brand red and the real
  logo (not the old layout, not an invented palette). A design canvas with every screen was
  shared and approved before this build started.
- **PDF report** (`lib/core/services/pdf_report_service.dart`) — a full rewrite, replacing
  `SupportClass/PdfGenerator.java` (1,379 lines of manual `Canvas`/`Paint` pixel-position
  drawing — the actual source of the "outdated, misaligned" report that was flagged).
  This version uses the `pdf` package's layout widgets (`pw.Table`, `Row`/`Column`,
  `Expanded`) so spacing and alignment are computed, not hand-placed, and stay correct
  regardless of name/label length. Letterhead, patient/device info table, 12-lead grid,
  rhythm strip, and calibration footer (paper speed, filter, gain).
- **Home screen connect state** — disconnected reads as visibly disabled (dimmed "New ECG"
  button) with a pulsing "tap to connect" affordance (`lib/modules/home/widgets/
  ripple_pulse.dart`, replacing the original's `layout_ripplepulse`); connected shows a
  solid, highlighted brand-red card with the device name and enables the CTA.
- **Online/offline handling** — `ConnectivityService` (GetX service wrapping
  `connectivity_plus`) plus a local SQLite queue (`EcgLocalDataSource`): every recording
  saves locally first, uploads opportunistically, and a dedicated "Manage Offline Reports"
  screen shows what's pending/failed with a manual retry — same shape as the original's
  `NetworkLiveData` + `PrefHelper.ECGDataList` queue, on a query-able store instead of a
  serialized prefs blob.
- **Architecture** — the exact `lib/{core,data,modules,routes,widgets,theme}` structure
  requested, GetX for state/DI/routing throughout.

## The BLE caveat — read before relying on iOS connectivity

The device hardware was confirmed (by you, in this conversation) to support BLE. But **this
codebase has no existing BLE implementation to read real values from** — only classic
Bluetooth SPP exists in the Android source. `parseData.java` in *this* repo already has
BLE-shaped plumbing (`bytesPerSample()`, a `sampleCount`/offset-based multi-sample parser,
comments about "a single BLE notification can carry several samples"), which tells me BLE
support was planned — but the actual GATT service/characteristic UUIDs and the real BLE
packet-batching format are not in the code anywhere I could find.

So: `lib/core/services/bluetooth/ble_transport.dart` and `bt_protocol.dart`'s
`bleServiceUuid`/`bleRxCharacteristicUuid`/`bleTxCharacteristicUuid` are **placeholders**,
clearly marked in the code. `EcgEngine` already walks multiple samples per payload if the
firmware batches them (matching the newer `parseData.java`'s intent), so the *parsing* side
is ready — but **the iOS/BLE connection path will not talk to real hardware until someone
with the firmware spec fills in the real UUIDs and confirms the batching format**. Android
via classic SPP needs none of this and should work against real hardware as-is (modulo the
usual "verify on a real device" caveat below).

## What's simplified or not ported

- **Automated ECG measurements** (HR, PR, QRS, QT, QTc — the `hr`/`pr`/`qrs`/`qt`/`qtc`/
  `qt_by_qtc` upload fields) — the analysis algorithm that computes these wasn't found in
  the Android source in the time available. They're sent as empty strings; wire in the real
  algorithm (or confirm the server computes them) before relying on these values downstream.
- **Push notifications** (`MyFirebaseMessagingService`, the `device_token` sent at login) —
  not wired up; login sends an empty `device_token`.
- **Doctor signature capture, patient photo/signature capture** — settings fields exist
  (`doctorSignaturePath`) but there's no capture UI yet.
- **Report-limit paywall** (`report_limit`/`report_limit_enabled` from `api/get-token`,
  the "recharge" dialog in `MainActivity`) — the data is fetched and stored but no UI gates
  new recordings on it yet.
- Multi-page / multi-report-type PDF variants (the original had `4x3`/`6x2`/`12x1` layout
  options) — this port always uses the 12-lead-grid + rhythm-strip layout.
- Fonts: deliberately using the platform default (system-ui), same as the original app,
  rather than a custom typeface that would need bundling or a runtime download — keeps the
  app fully functional offline from first launch.

## Test credentials

`staff1@lifeline.com` / `staff1@lifeline.com` were shared for testing. Those are **not**
committed anywhere in this code — the live production API was not called with them from
this sandboxed session (no hardware to actually exercise the recording flow with, and
unexplained login/API activity against a live account shouldn't happen without you driving
it). Use them yourself once you run the app to test the real login flow.

## What's verified in this session

- `flutter analyze` — clean across `lib/` (a handful of harmless `prefer_const_constructors`
  info-level lints only).
- `flutter test` — unit tests on the ported signal-processing logic: `ParseData`'s byte
  joining (`joinMsbLsb`/`joinBytes`, matched against hand-computed expected values),
  aux-lead derivation, hardware-version byte width, and lead-off status decoding (including
  a same-bit quirk shared between two electrodes that's in the original protocol mapping and
  preserved here); plus a check that every FIR coefficient bank is exactly 201 taps and
  symmetric (linear-phase), confirming the programmatic extraction from the Java source
  didn't corrupt anything. A full app-boot **widget** test was attempted first but hangs
  indefinitely in this sandbox — `GetStorage`/`connectivity_plus`/similar plugins need a
  real platform to answer their platform-channel calls, which the bare `flutter test` VM
  here doesn't provide. Run `flutter run` on a device/emulator/simulator to verify the UI
  boots and navigates.
- Programmatic extraction (not hand-retyping) of the FIR filter coefficients, to eliminate
  transcription risk on ~1,000 floating-point values.

**Not verified** (no Android/iOS SDKs, real hardware, or a real platform runtime in this
sandbox):
- `flutter build apk` / `flutter build ios` — full builds.
- The UI actually rendering/navigating on a device or emulator.
- Connecting to a real ECG device (classic SPP or BLE).
- The real API calls against `cloudecg.drcardio.in` (login, upload).
- Signal fidelity against a known-good recording.

## Project layout

```
flutter_app/lib/
  core/
    constants/     api_constants.dart, app_assets.dart
    network/       dio_client.dart (bearer-token interceptor)
    services/
      bluetooth/   protocol, frame parser, classic-SPP + BLE transports, BluetoothService
      ecg/         ecg_data, ecg_filter (+ FIR coefficients), parse_data, ecg_engine
      storage_service.dart, connectivity_service.dart
      pdf_report_service.dart, csv_export_service.dart
  data/
    models/        user, patient, ecg_record
    datasources/   remote (auth, ecg upload) + local (sqflite)
    repositories/  auth_repository, ecg_repository (offline-first sync)
  modules/         splash, onboarding, login, home, device_scan, patient_info, live_ecg,
                   pdf_viewer, reports, load_data, offline_reports, my_account, my_profile,
                   settings, help — each with bindings/controllers/views (+ widgets)
  routes/          app_routes.dart, app_pages.dart
  theme/           app_colors.dart, app_text_styles.dart, app_theme.dart
```

## Getting started

```
cd flutter_app
flutter pub get
flutter run   # Android for the classic-SPP path; iOS needs the BLE UUIDs filled in first
```
