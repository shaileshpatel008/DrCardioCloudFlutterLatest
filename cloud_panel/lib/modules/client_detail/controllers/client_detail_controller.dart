import 'package:get/get.dart';

import '../../../core/base/paged_list_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/navigation.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/models/network_models.dart';
import '../../../data/models/paged.dart';
import '../../../data/repositories/network_repository.dart';
import '../../../routes/app_routes.dart';
import '../../staff/widgets/staff_form_dialog.dart';

class ClientDetailController extends GetxController {
  final _repo = ClientRepository();
  late final int id = int.tryParse(Get.parameters['id'] ?? '') ?? 0;

  final client = Rxn<ClientModel>();
  final loading = true.obs;
  final error = RxnString();
  final tab = 0.obs; // 0 staff, 1 devices

  late final ClientStaffList staff;

  @override
  void onInit() {
    super.onInit();
    staff = Get.put(ClientStaffList(id, this), tag: 'client-staff-$id');
    load();
  }

  @override
  void onClose() {
    Get.delete<ClientStaffList>(tag: 'client-staff-$id');
    super.onClose();
  }

  Future<void> load() async {
    loading.value = client.value == null;
    error.value = null;
    try {
      client.value = await _repo.detail(id);
    } on ApiException catch (e) {
      error.value = e.message;
    } finally {
      loading.value = false;
    }
  }

  Future<void> edit() async {
    final saved = await Get.toNamed(AppRoutes.clientEditPath(id));
    if (saved == true) load();
  }

  Future<void> delete() async {
    final c = client.value;
    if (c == null) return;
    final ok = await AppDialogs.confirm(
      title: 'Delete ${c.hospitalName}?',
      message: 'The client account ${c.email} will be removed and can no longer sign in.',
    );
    if (!ok) return;
    try {
      AppToast.success(await _repo.delete(id));
      closeRoute(true, AppRoutes.clients);
    } on ApiException catch (e) {
      AppToast.error(e.message);
    }
  }

  void openEcgRecords() {
    final c = client.value;
    if (c == null) return;
    Get.offAllNamed(AppRoutes.ecgRecords, parameters: {'hospital_id': '${c.clientId}', 'hospital_name': c.hospitalName});
  }
}

/// The "Staff" tab of a client: paginated, with add / edit / delete.
class ClientStaffList extends PagedListController<StaffModel> {
  ClientStaffList(this.clientUserId, this.parent);

  final int clientUserId;
  final ClientDetailController parent;
  final _clients = ClientRepository();
  final _staff = StaffRepository();

  @override
  String get defaultSort => 'name';

  @override
  Future<Paged<StaffModel>> fetch(query) => _clients.staff(clientUserId, query);

  Future<void> add() async {
    final c = parent.client.value;
    if (c == null) return;
    if (await StaffFormDialog.open(clientId: c.clientId, clientName: c.hospitalName)) {
      load(toPage: 1);
      parent.load();
    }
  }

  Future<void> edit(StaffModel s) async {
    try {
      final full = await _staff.detail(s.id);
      if (await StaffFormDialog.open(staff: full, clientName: parent.client.value?.hospitalName)) refreshList();
    } on ApiException catch (e) {
      AppToast.error(e.message);
    }
  }

  Future<void> delete(StaffModel s) async {
    final ok = await AppDialogs.confirm(
      title: 'Delete ${s.name}?',
      message: '${s.email} will no longer be able to sign in to the Dr. Cardio app.',
    );
    if (!ok) return;
    try {
      AppToast.success(await _staff.delete(s.id));
      refreshList();
      parent.load();
    } on ApiException catch (e) {
      AppToast.error(e.message);
    }
  }
}
