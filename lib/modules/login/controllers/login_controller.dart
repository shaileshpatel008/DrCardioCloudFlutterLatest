import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

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

  /// Port of `SignInActivity`'s `checkBoxAgreement` — must be checked
  /// before `login()` proceeds, same as the original's
  /// `!checkBoxAgreement.isChecked()` guard on its Sign In button.
  final RxBool agreedToTerms = false.obs;

  /// True only after a submit attempt was blocked by [agreedToTerms]
  /// being false, so the inline error appears on the button press that
  /// needed it rather than the moment the screen loads.
  final RxBool showAgreementError = false.obs;

  void toggleObscure() => obscurePassword.value = !obscurePassword.value;

  void setAgreedToTerms(bool value) {
    agreedToTerms.value = value;
    if (value) showAgreementError.value = false;
  }

  Future<void> openPrivacyPolicy() => launchUrl(Uri.parse('https://drcardio.in/privacy-policy/'), mode: LaunchMode.externalApplication);

  Future<void> openTermsAndConditions() =>
      launchUrl(Uri.parse('https://drcardio.in/terms-of-service-agreement/'), mode: LaunchMode.externalApplication);

  Future<void> login() async {
    if (!formKey.currentState!.validate()) return;
    if (!agreedToTerms.value) {
      showAgreementError.value = true;
      AppToast.warning('Please agree to the Privacy Policy and Terms and Conditions.', title: 'Agreement required');
      return;
    }
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
