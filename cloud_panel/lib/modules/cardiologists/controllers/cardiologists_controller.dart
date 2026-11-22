import 'package:get/get.dart';

import '../../../core/base/paged_list_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/models/network_models.dart';
import '../../../data/models/paged.dart';
import '../../../data/repositories/network_repository.dart';
import '../../shell/shell_controller.dart';
import '../widgets/cardiologist_form.dart';
import '../widgets/cardiologist_view_panel.dart';

class CardiologistsController extends PagedListController<CardiologistModel> {
  final _repo = CardiologistRepository();

  @override
  String get defaultSort => 'name';

  @override
  void onInit() {
    sortAsc.value = true;
    perPage.value = 12;
    super.onInit();
  }

  @override
  void setPerPage(int n) {
    // Card grid reads better in multiples of 3 / 4.
    super.setPerPage(n == 10 ? 12 : n);
  }

  @override
  Future<Paged<CardiologistModel>> fetch(query) => _repo.list(query);

  Future<void> add() async {
    if (await CardiologistForm.open()) {
      load(toPage: 1);
      Get.find<ShellController>().refreshCounts();
    }
  }

  Future<void> edit(CardiologistModel c) async {
    if (await CardiologistForm.open(existing: c)) refreshList();
  }

  Future<void> view(CardiologistModel c) async {
    final action = await CardiologistViewPanel.open(c.id);
    if (action == 'edit') edit(c);
    if (action == 'delete') delete(c);
  }

  Future<void> delete(CardiologistModel c) async {
    final ok = await AppDialogs.confirm(
      title: 'Delete ${c.name}?',
      message: '${c.email} will no longer be able to sign in or receive ECGs for review.',
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
