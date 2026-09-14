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
    _persist(user);
    return user;
  }

  Future<UserModel> refreshToken() async {
    final user = await _remote.refreshToken(_storage.userId);
    _persist(user);
    return user;
  }

  Future<void> logout() => _storage.clearSession();

  void _persist(UserModel user) {
    _storage.isUserLoggedIn = true;
    _storage.userId = user.userId;
    _storage.userName = user.name;
    _storage.userEmail = user.email;
    _storage.token = user.rememberToken;
    _storage.reportLimitEnabled = user.reportLimitEnabled;
    _storage.reportLimit = user.reportLimit;
  }
}
