import '../../core/services/storage_service.dart';
import '../datasources/remote/auth_remote_datasource.dart';
import '../models/user_model.dart';

class AuthRepository {
  AuthRepository({AuthRemoteDataSource? remote}) : _remote = remote ?? AuthRemoteDataSource();

  final AuthRemoteDataSource _remote;
  final _storage = StorageService.instance;

  bool get isLoggedIn => _storage.isUserLoggedIn;

  Future<UserModel> login(String email, String password) async {
    final user = await _remote.login(email: email, password: password);
    await _persist(user);
    return user;
  }

  Future<UserModel> refreshToken() async {
    final user = await _remote.refreshToken(_storage.userId);
    await _persist(user);
    return user;
  }

  Future<void> logout() => _storage.clearSession();

  /// Awaited by [login]/[refreshToken] before they return, so the caller
  /// (e.g. `LoginController`, which navigates to Home right after) can't
  /// race ahead of the disk write session state depends on.
  Future<void> _persist(UserModel user) => _storage.writeSession(
        isUserLoggedIn: true,
        userId: user.userId,
        userName: user.name,
        userEmail: user.email,
        token: user.rememberToken,
        reportLimitEnabled: user.reportLimitEnabled,
        reportLimit: user.reportLimit,
      );
}
