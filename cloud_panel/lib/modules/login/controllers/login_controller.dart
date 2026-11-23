import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/demo/demo_mode.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../routes/app_routes.dart';

class LoginController extends GetxController {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController(text: StorageService.instance.rememberedEmail ?? '');
  final password = TextEditingController();

  final remember = true.obs;
  final loading = false.obs;
  final error = RxnString();
  final emailError = RxnString();

  final _auth = Get.find<AuthService>();

  Future<void> submit() async {
    error.value = null;
    emailError.value = null;
    if (!(formKey.currentState?.validate() ?? false)) return;
    loading.value = true;
    try {
      final user = await _auth.login(email.text, password.text, remember: remember.value);
      AppToast.success('Welcome back, ${user.name}.');
      Get.offAllNamed(AppRoutes.dashboard);
    } on ApiException catch (e) {
      emailError.value = e.errorFor('email');
      error.value = emailError.value == null ? e.message : null;
    } finally {
      loading.value = false;
    }
  }

  /// Demo build: fill in a sample account and sign in.
  void demoSignIn(DemoAccount account) {
    email.text = account.email;
    password.text = DemoAccount.password;
    submit();
  }

  Future<String> sendReset(String address) => AuthRepository().forgotPassword(address);

  @override
  void onClose() {
    email.dispose();
    password.dispose();
    super.onClose();
  }
}
