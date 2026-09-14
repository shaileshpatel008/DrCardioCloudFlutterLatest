import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/app_logger.dart';
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
  final RxnString errorMessage = RxnString();

  void toggleObscure() => obscurePassword.value = !obscurePassword.value;

  Future<void> login() async {
    if (!formKey.currentState!.validate()) return;
    isLoading.value = true;
    errorMessage.value = null;
    try {
      await _repository.login(emailController.text.trim(), passwordController.text);
      Get.offAllNamed(AppRoutes.home);
    } on ApiStatusException catch (e, st) {
      AppLogger.w('Login rejected by server', e, st);
      errorMessage.value = e.message;
    } catch (e, st) {
      AppLogger.e('Login failed', e, st);
      errorMessage.value = 'Could not sign in. Check your connection and try again.';
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
