import 'package:get/get.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/models/ecg_record_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/ecg_repository.dart';
import '../../../routes/app_routes.dart';
import '../../ecg_records/ecg_actions.dart';

class EcgDetailController extends GetxController {
  final _repo = EcgRepository();

  late final int id = int.tryParse(Get.parameters['id'] ?? '') ?? 0;
  final record = Rxn<EcgRecord>();
  final loading = true.obs;
  final error = RxnString();

  /// 0 = ECG recording, 1 = cardiologist report (merged PDF).
  final docTab = 0.obs;

  UserModel? get user => Get.find<AuthService>().current;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    loading.value = record.value == null;
    error.value = null;
    try {
      record.value = await _repo.detail(id);
    } on ApiException catch (e) {
      error.value = e.message;
    } finally {
      loading.value = false;
    }
  }

  Future<void> delete() async {
    final r = record.value;
    if (r == null) return;
    if (await EcgRecordActions.delete(r)) Get.back(result: true);
  }

  Future<void> reassign() async {
    final r = record.value;
    if (r != null && await EcgRecordActions.reassign(r)) load();
  }

  Future<void> assign() async {
    final r = record.value;
    if (r != null && await EcgRecordActions.assign(r)) load();
  }

  Future<void> diagnose() async {
    final changed = await Get.toNamed(AppRoutes.diagnosePath(id));
    if (changed == true) load();
  }
}
