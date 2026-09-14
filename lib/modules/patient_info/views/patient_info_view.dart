import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/patient_info_controller.dart';

class PatientInfoView extends GetView<PatientInfoController> {
  const PatientInfoView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patient Details')),
      body: Form(
        key: controller.formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: controller.idController,
                    decoration: const InputDecoration(labelText: 'Patient ID'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: controller.nameController,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller.ageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Age'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Obx(() => DropdownButtonFormField<String>(
                        initialValue: controller.sex.value,
                        decoration: const InputDecoration(labelText: 'Sex'),
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(value: 'Female', child: Text('Female')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (v) {
                          if (v != null) controller.setSex(v);
                        },
                      )),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller.heightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Height (cm)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: controller.weightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Weight (kg)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: controller.bpController,
                    decoration: const InputDecoration(labelText: 'BP'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: controller.medicationsController,
              decoration: const InputDecoration(labelText: 'Medications', hintText: 'e.g. Metoprolol, Aspirin'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: controller.commentsController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Clinical notes', hintText: 'Add comments for this recording…'),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: controller.continueToRecording,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Continue to Recording'),
            ),
          ],
        ),
      ),
    );
  }
}
