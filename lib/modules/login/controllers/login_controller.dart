import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/datasources/remote/auth_remote_datasource.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../routes/app_routes.dart';

class LoginController extends GetxController {
  LoginController({AuthRepository? repository}) : _repository = repository ?? AuthRepository();

  final AuthRepository _repository;

  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final RxBool obscurePassword = true.obs;
  final RxBool isLoading = false.obs;

  void toggleObscure() => obscurePassword.value = !obscurePassword.value;

  Future<void> login() async {
    if (!formKey.currentState!.validate()) return;
    isLoading.value = true;
    try {
      await _repository.login(emailController.text.trim(), passwordController.text);
      Get.offAllNamed(AppRoutes.home);
    } on ApiStatusException catch (e, st) {
      AppLogger.w('Login rejected by server', e, st);
      AppToast.error(e.message, title: 'Sign-in failed');
    } catch (e, st) {
      AppLogger.e('Login failed', e, st);
      AppToast.error('Could not sign in. Check your connection and try again.', title: 'Sign-in failed');
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
