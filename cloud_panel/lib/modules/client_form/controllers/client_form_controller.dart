import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/navigation.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/select_field.dart';
import '../../../data/models/paged.dart';
import '../../../data/repositories/network_repository.dart';
import '../../../routes/app_routes.dart';

/// Add / edit client — every field of the web form (client/add, client/{id}/edit).
class ClientFormController extends GetxController {
  final _repo = ClientRepository();
  final formKey = GlobalKey<FormState>();

  late final int? editId = int.tryParse(Get.parameters['id'] ?? '');
  bool get editing => editId != null;

  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  final hospital = TextEditingController();
  final doctor = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final reportLimit = TextEditingController(text: '0');
  final webhook = TextEditingController();
  final patientUrl = TextEditingController();

  final cardiologist = Rxn<LookupItem>();
  final reportLimitOn = false.obs;
  final multiHospital = false.obs;
  final defaultStaff = false.obs;
  final patientApiOn = false.obs;
  final devices = <TextEditingController>[TextEditingController()].obs;

  final loading = false.obs;
  final saving = false.obs;
  final errors = <String, String>{}.obs;
  final loadError = RxnString();

  @override
  void onInit() {
    super.onInit();
    if (editing) _load();
  }

  Future<void> _load() async {
    loading.value = true;
    try {
      final c = await _repo.detail(editId!);
      name.text = c.name;
      email.text = c.email;
      hospital.text = c.hospitalName;
      doctor.text = c.doctorName ?? '';
      phone.text = c.phoneNumber ?? '';
      address.text = c.address ?? '';
      reportLimitOn.value = c.reportLimitEnabled;
      reportLimit.text = '${c.reportLimit}';
      multiHospital.value = c.multiHospitalAccess;
      webhook.text = c.webhookUrl ?? '';
      patientApiOn.value = c.getPatientApiEnabled;
      patientUrl.text = c.getPatientUrl ?? '';
      if (c.cardiologistId != null) cardiologist.value = LookupItem(c.cardiologistId!, c.cardiologistName ?? 'Cardiologist');
    } on ApiException catch (e) {
      loadError.value = e.message;
    } finally {
      loading.value = false;
    }
  }

  Future<void> pickCardiologist() async {
    final r = await SelectSheet.pick<LookupItem>(
      title: 'Cardiologist',
      load: LookupRepository().cardiologists,
      labelOf: (i) => i.name,
      selected: cardiologist.value,
    );
    if (r?.value != null) cardiologist.value = r!.value;
  }

  void addDevice() => devices.add(TextEditingController());

  void removeDevice(int i) {
    devices[i].dispose();
    devices.removeAt(i);
    if (devices.isEmpty) devices.add(TextEditingController());
  }

  String? error(String field) => errors[field];

  Future<void> save() async {
    errors.clear();
    if (!(formKey.currentState?.validate() ?? false)) {
      AppToast.error('Please fix the highlighted fields.');
      return;
    }
    saving.value = true;
    final body = <String, dynamic>{
      'name': name.text.trim(),
      'email': email.text.trim(),
      'hospital_name': hospital.text.trim(),
      'doctor_name': doctor.text.trim(),
      'phone_number': phone.text.trim(),
      'address': address.text.trim(),
      'cardiologist': multiHospital.value ? null : cardiologist.value?.id,
      'report_limit_enabled': reportLimitOn.value,
      'report_limit': int.tryParse(reportLimit.text.trim()) ?? 0,
      'multi_hospital_access': multiHospital.value,
      'webhook_url': webhook.text.trim(),
      'get_patient_api_enabled': patientApiOn.value,
      'get_patient_url': patientApiOn.value ? patientUrl.text.trim() : '',
      if (password.text.isNotEmpty) 'password': password.text,
      if (password.text.isNotEmpty) 'password_confirmation': confirm.text,
      if (!editing) 'create_default_staff': defaultStaff.value,
      if (!editing) 'devices': devices.map((d) => d.text.trim()).where((d) => d.isNotEmpty).toList(),
    }..removeWhere((k, v) => v == null);

    try {
      final msg = editing ? await _repo.update(editId!, body) : await _repo.create(body);
      AppToast.success(msg);
      closeRoute(true, AppRoutes.clients);
    } on ApiException catch (e) {
      errors.assignAll(e.fieldErrors);
      AppToast.error(e.fieldErrors.isEmpty ? e.message : 'Please fix the highlighted fields.');
    } finally {
      saving.value = false;
    }
  }

  /// Email the default staff login will get ("name-staff@domain").
  String get defaultStaffEmail {
    final parts = email.text.trim().split('@');
    if (parts.length != 2 || parts[0].isEmpty) return 'your-email-staff@domain';
    return '${parts[0]}-staff@${parts[1]}';
  }

  @override
  void onClose() {
    for (final c in [name, email, password, confirm, hospital, doctor, phone, address, reportLimit, webhook, patientUrl, ...devices]) {
      c.dispose();
    }
    super.onClose();
  }
}
