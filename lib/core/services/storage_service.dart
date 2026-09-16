import 'package:get_storage/get_storage.dart';

/// Port of `PrefHelper` (Android `SharedPreferences` wrapper) onto
/// `GetStorage`. Key names match the original 1:1 where they hold data the
/// rest of this app's logic depends on (auth/session), so nothing here is
/// arbitrary renaming.
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  late final GetStorage _box;

  Future<void> init() async {
    await GetStorage.init('drcardio');
    _box = GetStorage('drcardio');
  }

  // --- Session (mirrors PrefHelper keys used in SignInActivity) ---
  bool get isUserLoggedIn => _box.read('isUserLoggedIn') ?? false;
  set isUserLoggedIn(bool v) => _box.write('isUserLoggedIn', v);

  String get userName => _box.read('UserName') ?? '';
  set userName(String v) => _box.write('UserName', v);

  int get userId => _box.read('UserID') ?? 0;
  set userId(int v) => _box.write('UserID', v);

  String get userEmail => _box.read('UserEmail') ?? '';
  set userEmail(String v) => _box.write('UserEmail', v);

  String get token => _box.read('Token') ?? '';
  set token(String v) => _box.write('Token', v);

  String get savedDeviceName => _box.read('SavedDeviceName') ?? '';
  set savedDeviceName(String v) => _box.write('SavedDeviceName', v);

  /// The MAC address (classic SPP) or peripheral id (BLE) of the last
  /// device successfully connected to — port of `settings.saved_address`,
  /// used the same way `MainActivity.checkLastConnectedDevice()` does: to
  /// reconnect directly on app launch without a fresh scan (a device
  /// already connected doesn't advertise, so it wouldn't show up in one
  /// anyway). Set unconditionally on every successful connection,
  /// independent of [savedDeviceName] (which only updates once the
  /// server has actually validated the device).
  String get savedDeviceAddress => _box.read('saved_device_address') ?? '';
  set savedDeviceAddress(String v) => _box.write('saved_device_address', v);

  /// [TransportType.name] for [savedDeviceAddress] — classic-SPP and BLE
  /// devices reconnect differently, so this has to be remembered
  /// alongside the address, not assumed.
  String get savedDeviceTransport => _box.read('saved_device_transport') ?? '';
  set savedDeviceTransport(String v) => _box.write('saved_device_transport', v);

  bool get hasSeenOnboarding => _box.read('hasSeenOnboarding') ?? false;
  set hasSeenOnboarding(bool v) => _box.write('hasSeenOnboarding', v);

  /// Port of `settings.test_mode` ("ECG"/"Test" mode toggle on the
  /// Settings screen). Test mode tells the device to output its built-in
  /// fixed calibration waveform (`CMD_TEST_START`) instead of real
  /// acquisition (`CMD_START`) — same wire protocol, same chart pipeline,
  /// just a known-good signal instead of a patient's.
  bool get testMode => _box.read('settings_test_mode') ?? false;
  set testMode(bool v) => _box.write('settings_test_mode', v);

  // --- Report-limit / plan quota (from api/get-token) ---
  bool get reportLimitEnabled => _box.read('reportLimitEnabled') ?? false;
  set reportLimitEnabled(bool v) => _box.write('reportLimitEnabled', v);

  int get reportLimit => _box.read('reportLimit') ?? 0;
  set reportLimit(int v) => _box.write('reportLimit', v);

  // --- Settings (mirrors SupportClass/settings.java keys) ---
  String get filter => _box.read('settings_filter') ?? '0 to 40 Hz';
  set filter(String v) => _box.write('settings_filter', v);

  String get gain => _box.read('settings_gain') ?? '1';
  set gain(String v) => _box.write('settings_gain', v);

  String get actualGain => _box.read('settings_actualgain') ?? '6';
  set actualGain(String v) => _box.write('settings_actualgain', v);

  bool get autoSave => _box.read('settings_auto_save') ?? true;
  set autoSave(bool v) => _box.write('settings_auto_save', v);

  /// "have_to_assign_cardiologist" sent with every upload.
  bool get autoAssignCardiologist => _box.read('auto_assign') ?? false;
  set autoAssignCardiologist(bool v) => _box.write('auto_assign', v);

  /// Report paper speed in mm/s (25 or 50), matches `settings.xAxisScale`.
  int get xAxisScale => _box.read('settings_xAxisScale') ?? 25;
  set xAxisScale(int v) => _box.write('settings_xAxisScale', v);

  String get doctorSignaturePath => _box.read('settings_doctor_signature_path') ?? '';
  set doctorSignaturePath(String v) => _box.write('settings_doctor_signature_path', v);

  String get doctorName => _box.read('settings_doctor_name') ?? '';
  set doctorName(String v) => _box.write('settings_doctor_name', v);

  String get doctorAddress => _box.read('settings_doctor_address') ?? '';
  set doctorAddress(String v) => _box.write('settings_doctor_address', v);

  String get doctorContactNo => _box.read('settings_doctor_contactno') ?? '';
  set doctorContactNo(String v) => _box.write('settings_doctor_contactno', v);

  String get doctorEmail => _box.read('settings_doctor_email') ?? '';
  set doctorEmail(String v) => _box.write('settings_doctor_email', v);

  String get clinicName => _box.read('settings_clinic_name') ?? '';
  set clinicName(String v) => _box.write('settings_clinic_name', v);

  Future<void> clearSession() async {
    await _box.remove('isUserLoggedIn');
    await _box.remove('UserName');
    await _box.remove('UserID');
    await _box.remove('UserEmail');
    await _box.remove('Token');
  }

  /// Persists the whole session atomically-enough-in-practice and, unlike
  /// the plain setters above (which fire-and-forget `_box.write`, a `set`
  /// can't return the Future), actually awaits every disk flush. Without
  /// this, a login immediately followed by the app being killed (exactly
  /// what testing "does login survive a restart" looks like) can lose the
  /// write if the process dies before GetStorage's queued flush runs.
  Future<void> writeSession({
    required bool isUserLoggedIn,
    required int userId,
    required String userName,
    required String userEmail,
    required String token,
    required bool reportLimitEnabled,
    required int reportLimit,
  }) async {
    await _box.write('isUserLoggedIn', isUserLoggedIn);
    await _box.write('UserID', userId);
    await _box.write('UserName', userName);
    await _box.write('UserEmail', userEmail);
    await _box.write('Token', token);
    await _box.write('reportLimitEnabled', reportLimitEnabled);
    await _box.write('reportLimit', reportLimit);
  }
}
