import 'package:get/get.dart';

import '../../../core/base/paged_list_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/select_field.dart';
import '../../../data/models/network_models.dart';
import '../../../data/models/paged.dart';
import '../../../data/repositories/network_repository.dart';
import '../../../routes/app_routes.dart';
import '../../shell/shell_controller.dart';

class ClientsController extends PagedListController<ClientModel> {
  final _repo = ClientRepository();
  final cardiologist = Rxn<LookupItem>();

  @override
  Map<String, dynamic> get extraQuery => {'cardiologist_id': cardiologist.value?.id};

  @override
  Future<Paged<ClientModel>> fetch(ListQuery query) => _repo.list(query);

  Future<void> pickCardiologist() async {
    final r = await SelectSheet.pick<LookupItem>(
      title: 'Cardiologist',
      load: LookupRepository().cardiologists,
      labelOf: (i) => i.name,
      selected: cardiologist.value,
      allowClear: true,
      clearLabel: 'All cardiologists',
    );
    if (r == null) return;
    cardiologist.value = r.value;
    load(toPage: 1);
  }

  Future<void> add() async {
    final saved = await Get.toNamed(AppRoutes.clientNew);
    if (saved == true) {
      load(toPage: 1);
      Get.find<ShellController>().refreshCounts();
    }
  }

  Future<void> open(ClientModel c) async {
    await Get.toNamed(AppRoutes.clientPath(c.id));
    refreshList();
  }

  Future<void> edit(ClientModel c) async {
    final saved = await Get.toNamed(AppRoutes.clientEditPath(c.id));
    if (saved == true) refreshList();
  }

  Future<void> delete(ClientModel c) async {
    final ok = await AppDialogs.confirm(
      title: 'Delete ${c.hospitalName}?',
      message: 'The client account ${c.email} will be removed and can no longer sign in. Its ECG records stay in the system.',
    );
    if (!ok) return;
    try {
      AppToast.success(await _repo.delete(c.id));
      refreshList();
      Get.find<ShellController>().refreshCounts();
    } on ApiException catch (e) {
      AppToast.error(e.message);
    }
  }
}
