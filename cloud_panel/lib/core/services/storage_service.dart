import 'package:get_storage/get_storage.dart';

/// Persisted session: the API token and the last signed-in user payload.
/// GetStorage uses localStorage on web and a file on Android / iOS.
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const _box = 'drcardio_panel';
  static const _kToken = 'token';
  static const _kUser = 'user';
  static const _kRemember = 'remember_email';
  static const _kSidebarCollapsed = 'sidebar_collapsed';

  late final GetStorage _storage;

  Future<void> init() async {
    await GetStorage.init(_box);
    _storage = GetStorage(_box);
  }

  String get token => _storage.read<String>(_kToken) ?? '';
  set token(String value) => _storage.write(_kToken, value);

  Map<String, dynamic>? get user {
    final raw = _storage.read(_kUser);
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  set user(Map<String, dynamic>? value) => value == null ? _storage.remove(_kUser) : _storage.write(_kUser, value);

  String? get rememberedEmail => _storage.read<String>(_kRemember);
  set rememberedEmail(String? value) => value == null ? _storage.remove(_kRemember) : _storage.write(_kRemember, value);

  bool get sidebarCollapsed => _storage.read<bool>(_kSidebarCollapsed) ?? false;
  set sidebarCollapsed(bool value) => _storage.write(_kSidebarCollapsed, value);

  Future<void> clearSession() async {
    await _storage.remove(_kToken);
    await _storage.remove(_kUser);
  }
}
