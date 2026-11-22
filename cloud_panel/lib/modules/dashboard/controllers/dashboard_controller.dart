import 'package:get/get.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/models/dashboard_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/ecg_repository.dart';
import '../../shell/shell_controller.dart';

class DashboardController extends GetxController {
  final _repo = EcgRepository();
  final data = Rxn<DashboardData>();
  final loading = true.obs;
  final error = RxnString();

  UserModel? get user => Get.find<AuthService>().current;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    loading.value = data.value == null;
    error.value = null;
    try {
      final d = await _repo.dashboard();
      data.value = d;
      Get.find<ShellController>().setCounts(d.counts);
    } on ApiException catch (e) {
      error.value = e.message;
    } catch (_) {
      error.value = 'Something went wrong. Please try again.';
    } finally {
      loading.value = false;
    }
  }
}
