# Demo data (for the DEMO_MODE build)

`assets/demo/demo_data.json` is what the demo build (`--dart-define=DEMO_MODE=true`)
shows: 8 hospitals, 5 cardiologists, 1 OEM partner, staff, devices and 162 ECG
records over 30 days. Everything is fictional (`*@example.com`).

It was captured from the real Panel API v2 so every JSON shape matches the live
API exactly. To regenerate it (local or staging copy of the Laravel project with
`laravel_api_v2` installed, **never production**):

1. Copy `DemoSeeder.php` to `database/seeders/` and seed an empty database:

   ```bash
   php artisan migrate:fresh --force && php artisan db:seed --class=DemoSeeder --force
   ```

2. Start the API (`php artisan serve`) and capture every screen's data
   (edit `BASE` in the script if it is not `http://127.0.0.1:8000/api/v2`):

   ```bash
   python3 export_fixtures.py raw.json
   ```

3. Convert it into the app asset:

   ```bash
   python3 build_asset.py raw.json ../../assets/demo/demo_data.json
   ```

The app moves every timestamp forward at start-up, so the data always looks
recent ("12 minutes ago", today's chart bar).
