import 'package:get/get.dart';

import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../routes/app_routes.dart';
import '../network/dio_client.dart';
import '../widgets/app_toast.dart';
import 'storage_service.dart';

/// App-wide session: who is signed in, and the single place that signs in,
/// refreshes and signs out. Registered permanently in main().
class AuthService extends GetxService {
  final _repo = AuthRepository();
  final _storage = StorageService.instance;

  final Rxn<UserModel> user = Rxn<UserModel>();

  bool get isLoggedIn => _storage.token.isNotEmpty && user.value != null;
  UserModel? get current => user.value;

  AuthService init() {
    final saved = _storage.user;
    if (_storage.token.isNotEmpty && saved != null) {
      user.value = UserModel.fromJson(saved);
    }
    DioClient.instance.onUnauthorized = _sessionExpired;
    return this;
  }

  Future<UserModel> login(String email, String password, {bool remember = true}) async {
    final result = await _repo.login(email, password);
    _storage.token = result.token;
    _storage.user = result.user.toJson();
    _storage.rememberedEmail = remember ? email.trim() : null;
    user.value = result.user;
    return result.user;
  }

  /// Re-reads role / menu / profile from the server (e.g. after a profile edit).
  Future<void> refreshMe() async {
    if (_storage.token.isEmpty) return;
    try {
      final fresh = await _repo.me();
      _storage.user = fresh.toJson();
      user.value = fresh;
    } catch (_) {
      // Keep the cached user; a 401 is handled by _sessionExpired.
    }
  }

  void setUser(UserModel updated) {
    _storage.user = updated.toJson();
    user.value = updated;
  }

  Future<void> logout() async {
    try {
      await _repo.logout();
    } catch (_) {}
    await _clear();
    Get.offAllNamed(AppRoutes.login);
  }

  bool _expiring = false;

  Future<void> _sessionExpired() async {
    if (_expiring || _storage.token.isEmpty) return;
    _expiring = true;
    await _clear();
    Get.offAllNamed(AppRoutes.login);
    AppToast.info('Your session has expired. Please sign in again.');
    _expiring = false;
  }

  Future<void> _clear() async {
    await _storage.clearSession();
    user.value = null;
  }
}
