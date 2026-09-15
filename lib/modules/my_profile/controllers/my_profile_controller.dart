import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/storage_service.dart';
import '../../../core/widgets/app_toast.dart';

class MyProfileController extends GetxController {
  final storage = StorageService.instance;

  late final nameController = TextEditingController(text: storage.doctorName.isEmpty ? storage.userName : storage.doctorName);
  late final clinicController = TextEditingController(text: storage.clinicName);
  late final addressController = TextEditingController(text: storage.doctorAddress);
  late final contactController = TextEditingController(text: storage.doctorContactNo);
  late final emailController = TextEditingController(text: storage.doctorEmail.isEmpty ? storage.userEmail : storage.doctorEmail);

  final RxBool isSaving = false.obs;

  Future<void> save() async {
    isSaving.value = true;
    storage.doctorName = nameController.text.trim();
    storage.clinicName = clinicController.text.trim();
    storage.doctorAddress = addressController.text.trim();
    storage.doctorContactNo = contactController.text.trim();
    storage.doctorEmail = emailController.text.trim();
    await Future.delayed(const Duration(milliseconds: 300));
    isSaving.value = false;
    Get.back();
    AppToast.success('Profile updated.');
  }

  @override
  void onClose() {
    nameController.dispose();
    clinicController.dispose();
    addressController.dispose();
    contactController.dispose();
    emailController.dispose();
    super.onClose();
  }
}
