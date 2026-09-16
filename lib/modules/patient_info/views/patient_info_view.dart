import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../theme/app_colors.dart';
import '../controllers/patient_info_controller.dart';

/// Redesign approved as "Option C · Compact & Dense": tight, sectioned
/// cards instead of a flat unstructured field list, a small red-dot
/// marker (not a per-section badge) on just the fields that are actually
/// required — only Full name and Gender — and a sticky bottom CTA instead
/// of one that scrolls with the content.
class PatientInfoView extends GetView<PatientInfoController> {
  const PatientInfoView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patient Details')),
      body: Form(
        key: controller.formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                children: [
                  const Text(
                    'Enter patient details before starting the recording',
                    style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'PATIENT IDENTITY',
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _CompactField(
                              label: 'Patient ID',
                              controller: controller.idController,
                              hintText: 'PT-00214',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CompactField(
                              label: 'Age',
                              controller: controller.ageController,
                              hintText: 'Years',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _CompactField(
                        label: 'Full name',
                        controller: controller.nameController,
                        hintText: "Patient's full name",
                        required: true,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      _GenderField(controller: controller),
                      const SizedBox(height: 4),
                      const Row(
                        children: [
                          _RequiredDot(),
                          SizedBox(width: 5),
                          Text('Required fields', style: TextStyle(color: AppColors.muted2, fontSize: 10.5, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Vitals (Height/Weight/BP) — hidden for now until the
                  // client confirms it's needed; not deleted, just not
                  // rendered, so it's a quick uncomment to bring back
                  // (heightController/weightController/bpController below
                  // stay wired in the controller either way):
                  //
                  // _SectionCard(
                  //   title: 'VITALS',
                  //   optionalTag: true,
                  //   children: [
                  //     Row(
                  //       children: [
                  //         Expanded(
                  //           child: _CompactField(
                  //             label: 'Height',
                  //             controller: controller.heightController,
                  //             hintText: 'cm',
                  //             keyboardType: TextInputType.number,
                  //           ),
                  //         ),
                  //         const SizedBox(width: 10),
                  //         Expanded(
                  //           child: _CompactField(
                  //             label: 'Weight',
                  //             controller: controller.weightController,
                  //             hintText: 'kg',
                  //             keyboardType: TextInputType.number,
                  //           ),
                  //         ),
                  //         const SizedBox(width: 10),
                  //         Expanded(
                  //           child: _CompactField(
                  //             label: 'BP',
                  //             controller: controller.bpController,
                  //             hintText: '120/80',
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //   ],
                  // ),
                  // const SizedBox(height: 12),

                  _SectionCard(
                    title: 'CLINICAL NOTES',
                    optionalTag: true,
                    children: [
                      _CompactField(
                        label: 'Medications',
                        controller: controller.medicationsController,
                        hintText: 'e.g. Metoprolol, Aspirin',
                      ),
                      const SizedBox(height: 10),
                      _CompactField(
                        label: 'Clinical notes',
                        controller: controller.commentsController,
                        hintText: 'Add comments for this recording…',
                        maxLines: 3,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                boxShadow: [BoxShadow(color: Color(0x1F201F1E), blurRadius: 20, offset: Offset(0, -8))],
              ),
              child: FilledButton.icon(
                onPressed: controller.continueToRecording,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continue to Recording'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequiredDot extends StatelessWidget {
  const _RequiredDot();
  @override
  Widget build(BuildContext context) => Container(
        width: 5,
        height: 5,
        decoration: const BoxDecoration(color: AppColors.brandRed, shape: BoxShape.circle),
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children, this.optionalTag = false});
  final String title;
  final List<Widget> children;
  final bool optionalTag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.muted2, letterSpacing: 0.5)),
              if (optionalTag) ...[
                const SizedBox(width: 6),
                const Text('optional', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.placeholder)),
              ],
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _CompactField extends StatelessWidget {
  const _CompactField({
    required this.label,
    required this.controller,
    this.hintText,
    this.required = false,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final bool required;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (required) ...[const _RequiredDot(), const SizedBox(width: 5)],
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
          ],
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink),
          decoration: InputDecoration(
            isDense: true,
            hintText: hintText,
            contentPadding: EdgeInsets.symmetric(horizontal: 13, vertical: maxLines > 1 ? 11 : 13),
          ),
        ),
      ],
    );
  }
}

class _GenderField extends StatelessWidget {
  const _GenderField({required this.controller});
  final PatientInfoController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RequiredDot(),
            SizedBox(width: 5),
            Text('Gender', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
          ],
        ),
        const SizedBox(height: 5),
        Obx(() => DropdownButtonFormField<String>(
              initialValue: controller.gender.value,
              hint: const Text('Select gender', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.placeholder)),
              validator: (v) => v == null ? 'Required' : null,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink),
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 13, vertical: 13)),
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (v) {
                if (v != null) controller.setGender(v);
              },
            )),
      ],
    );
  }
}
