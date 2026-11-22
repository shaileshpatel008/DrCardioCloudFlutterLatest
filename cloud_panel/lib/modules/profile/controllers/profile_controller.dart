import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/json_utils.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/network_repository.dart';

/// "My profile" — same fields per role as the web /edit-profile page.
class ProfileController extends GetxController {
  final _repo = ProfileRepository();
  final _auth = Get.find<AuthService>();
  final formKey = GlobalKey<FormState>();
  final passwordKey = GlobalKey<FormState>();

  final name = TextEditingController();
  final hospital = TextEditingController();
  final doctor = TextEditingController();
  final address = TextEditingController();
  final footer = TextEditingController();
  final themeColor = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();

  final loading = true.obs;
  final saving = false.obs;
  final savingPassword = false.obs;
  final errors = <String, String>{}.obs;
  final logoUrl = RxnString();
  final signatureUrl = RxnString();
  final newLogo = Rxn<({List<int> bytes, String name})>();
  final newSignature = Rxn<({List<int> bytes, String name})>();

  UserModel? get user => _auth.current;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    loading.value = true;
    try {
      final data = await _repo.get();
      _fill(data);
    } on ApiException catch (e) {
      AppToast.error(e.message);
    } finally {
      loading.value = false;
    }
  }

  void _fill(Map<String, dynamic> data) {
    final editable = asMap(data['editable']);
    name.text = asStringOr(data['name']);
    hospital.text = asStringOr(editable['hospital_name']);
    doctor.text = asStringOr(editable['doctor_name']);
    address.text = asStringOr(editable['address']);
    footer.text = asStringOr(editable['footer']);
    themeColor.text = asStringOr(data['theme_color']);
    final cardio = asMap(data['cardiologist']);
    logoUrl.value = asString(cardio['logo_url']) ?? asString(data['logo_url']);
    signatureUrl.value = asString(cardio['signature_url']);
    _auth.setUser(UserModel.fromJson(Map<String, dynamic>.from(data)..remove('editable')));
  }

  Future<({List<int> bytes, String name})?> _pickImage() async {
    final f = await FilePicker.pickFile(type: FileType.image);
    if (f == null) return null;
    final size = await f.length();
    if (size != null && size > 30 * 1024 * 1024) {
      AppToast.error('Please choose an image smaller than 30 MB.');
      return null;
    }
    final bytes = await f.readAsBytes();
    return (bytes: bytes.toList(), name: f.name);
  }

  Future<void> pickLogo() async => newLogo.value = await _pickImage() ?? newLogo.value;
  Future<void> pickSignature() async => newSignature.value = await _pickImage() ?? newSignature.value;

  Future<void> removeLogo() async {
    if (newLogo.value != null) {
      newLogo.value = null;
      return;
    }
    if (!await AppDialogs.confirm(title: 'Remove logo?', message: 'Your reports will no longer show this logo.', confirmLabel: 'Remove')) return;
    try {
      await _repo.deleteLogo();
      logoUrl.value = null;
      AppToast.success('Logo removed.');
    } on ApiException catch (e) {
      AppToast.error(e.message);
    }
  }

  Future<void> removeSignature() async {
    if (newSignature.value != null) {
      newSignature.value = null;
      return;
    }
    if (!await AppDialogs.confirm(title: 'Remove signature?', message: 'Your reports will no longer show this signature and stamp.', confirmLabel: 'Remove')) return;
    try {
      await _repo.deleteSignature();
      signatureUrl.value = null;
      AppToast.success('Signature removed.');
    } on ApiException catch (e) {
      AppToast.error(e.message);
    }
  }

  Map<String, dynamic> _baseFields() {
    final u = user;
    return {
      'name': name.text.trim(),
      if (u?.isClient ?? false) 'hospital_name': hospital.text.trim(),
      if (u?.isClient ?? false) 'doctor_name': doctor.text.trim(),
      if ((u?.isClient ?? false) || (u?.isCardiologist ?? false)) 'address': address.text.trim(),
      if (u?.isCardiologist ?? false) 'footer': footer.text.trim(),
      if ((u?.isOem ?? false) && themeColor.text.trim().isNotEmpty) 'theme_color': themeColor.text.trim(),
    };
  }

  Future<void> saveDetails() async {
    errors.clear();
    if (!(formKey.currentState?.validate() ?? false)) return;
    saving.value = true;
    try {
      final res = await _repo.update(_baseFields(), logo: newLogo.value, signature: newSignature.value);
      newLogo.value = null;
      newSignature.value = null;
      _fill(res.data);
      AppToast.success(res.message);
    } on ApiException catch (e) {
      errors.assignAll(e.fieldErrors);
      AppToast.error(e.message);
    } finally {
      saving.value = false;
    }
  }

  Future<void> savePassword() async {
    errors.clear();
    if (!(passwordKey.currentState?.validate() ?? false)) return;
    savingPassword.value = true;
    try {
      final res = await _repo.update({
        ..._baseFields(),
        'password': password.text,
        'password_confirmation': confirm.text,
      });
      password.clear();
      confirm.clear();
      AppToast.success('Password updated. Use it the next time you sign in.');
      _fill(res.data);
    } on ApiException catch (e) {
      errors.assignAll(e.fieldErrors);
      AppToast.error(e.message);
    } finally {
      savingPassword.value = false;
    }
  }

  @override
  void onClose() {
    for (final c in [name, hospital, doctor, address, footer, themeColor, password, confirm]) {
      c.dispose();
    }
    super.onClose();
  }
}
