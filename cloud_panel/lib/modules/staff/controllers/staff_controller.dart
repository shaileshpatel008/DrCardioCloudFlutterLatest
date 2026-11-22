import 'package:get/get.dart';

import '../../../core/base/paged_list_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/models/network_models.dart';
import '../../../data/models/paged.dart';
import '../../../data/repositories/network_repository.dart';
import '../../../routes/app_routes.dart';
import '../../shell/shell_controller.dart';
import '../widgets/staff_form_dialog.dart';

/// Two lists share this controller:
///  - Super Admin "Staff": every technician with their client (web /admin_staffs)
///  - Client "My Staff": the client's own technicians (web /staffs)
class StaffController extends PagedListController<StaffModel> {
  StaffController({required this.mine});

  final bool mine;
  final _repo = StaffRepository();

  @override
  String get defaultSort => 'name';

  @override
  void onInit() {
    sortAsc.value = true;
    super.onInit();
    if (mine && Get.parameters['add'] == '1') Future.delayed(const Duration(milliseconds: 400), add);
  }

  @override
  Future<Paged<StaffModel>> fetch(query) => mine ? _repo.myList(query) : _repo.adminList(query);

  Future<void> add() async {
    if (await StaffFormDialog.open(withCardiologist: mine)) {
      load(toPage: 1);
      Get.find<ShellController>().refreshCounts();
    }
  }

  Future<void> edit(StaffModel s) async {
    try {
      final full = await _repo.detail(s.id);
      final merged = StaffModel(
        id: full.id,
        name: full.name,
        email: full.email,
        phoneNumber: full.phoneNumber,
        clientId: full.clientId,
        cardiologistId: full.cardiologistId,
        cardiologistName: s.cardiologistName,
      );
      if (await StaffFormDialog.open(staff: merged, clientName: s.clientName, withCardiologist: mine)) refreshList();
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
      AppToast.success(await _repo.delete(s.id));
      refreshList();
      Get.find<ShellController>().refreshCounts();
    } on ApiException catch (e) {
      AppToast.error(e.message);
    }
  }

  void openClient(StaffModel s) {
    if (s.clientUserId != null) Get.toNamed(AppRoutes.clientPath(s.clientUserId!));
  }
}
