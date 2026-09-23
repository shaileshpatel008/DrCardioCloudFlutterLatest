import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../theme/app_colors.dart';
import '../controllers/my_profile_controller.dart';

class MyProfileView extends GetView<MyProfileController> {
  const MyProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.brandRed,
              child: Text(
                controller.nameController.text.isEmpty ? '?' : controller.nameController.text.substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 28),
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextField(controller: controller.nameController, decoration: const InputDecoration(labelText: 'Doctor name')),
          const SizedBox(height: 14),
          TextField(controller: controller.clinicController, decoration: const InputDecoration(labelText: 'Clinic / hospital')),
          const SizedBox(height: 14),
          TextField(controller: controller.addressController, decoration: const InputDecoration(labelText: 'Clinic address')),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: TextField(controller: controller.contactController, decoration: const InputDecoration(labelText: 'Contact number'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: controller.emailController, decoration: const InputDecoration(labelText: 'Email'))),
            ],
          ),
          const SizedBox(height: 24),
          Obx(() => FilledButton(
                onPressed: controller.isSaving.value ? null : controller.save,
                child: controller.isSaving.value
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Changes'),
              )),
        ],
      ),
    );
  }
}
