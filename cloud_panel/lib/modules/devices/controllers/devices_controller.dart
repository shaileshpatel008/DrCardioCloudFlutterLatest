import 'package:get/get.dart';

import '../../../core/base/paged_list_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/select_field.dart';
import '../../../data/models/network_models.dart';
import '../../../data/models/paged.dart';
import '../../../data/repositories/network_repository.dart';
import '../../shell/shell_controller.dart';
import '../widgets/device_form.dart';

class DevicesController extends PagedListController<DeviceModel> {
  final _repo = DeviceRepository();
  final hospital = Rxn<LookupItem>();

  @override
  String get defaultSort => 'device';

  @override
  Map<String, dynamic> get extraQuery => {'hospital_id': hospital.value?.id};

  @override
  void onInit() {
    sortAsc.value = true;
    super.onInit();
    if (Get.parameters['add'] == '1') Future.delayed(const Duration(milliseconds: 400), add);
  }

  @override
  Future<Paged<DeviceModel>> fetch(query) => _repo.list(query);

  Future<void> pickHospital() async {
    final r = await SelectSheet.pick<LookupItem>(
      title: 'Hospital',
      load: LookupRepository().hospitals,
      labelOf: (i) => i.name,
      selected: hospital.value,
      allowClear: true,
      clearLabel: 'All hospitals',
    );
    if (r == null) return;
    hospital.value = r.value;
    load(toPage: 1);
  }

  Future<void> add() async {
    if (await DeviceForm.open(presetHospital: hospital.value)) {
      load(toPage: 1);
      Get.find<ShellController>().refreshCounts();
    }
  }

  Future<void> edit(DeviceModel d) async {
    if (await DeviceForm.open(existing: d)) refreshList();
  }

  Future<void> delete(DeviceModel d) async {
    final ok = await AppDialogs.confirm(
      title: 'Delete device ${d.instrumentId}?',
      message: 'The device is unlinked from ${d.hospitalName ?? 'its hospital'} and can be registered again later.',
    );
    if (!ok) return;
    try {
      AppToast.success(await _repo.delete(d.id));
      refreshList();
      Get.find<ShellController>().refreshCounts();
    } on ApiException catch (e) {
      AppToast.error(e.message);
    }
  }
}
