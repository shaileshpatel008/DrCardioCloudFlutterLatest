import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';

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
                  Text(
                    controller.isEditMode
                        ? 'Update the patient details for this recording'
                        : 'Enter patient details before starting the recording',
                    style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 12.5),
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
                          Text('Required fields', style: TextStyle(color: AppColors.muted2, fontSize: 10.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'PATIENT PHOTO & SIGNATURE',
                    optionalTag: true,
                    children: [_PhotoSignatureRow(controller: controller)],
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
                icon: Icon(controller.isEditMode ? Icons.check : Icons.arrow_forward),
                label: Text(controller.isEditMode ? 'Save Changes' : 'Continue to Recording'),
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
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted2, letterSpacing: 0.5)),
              if (optionalTag) ...[
                const SizedBox(width: 6),
                const Text('optional', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.placeholder)),
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
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
          ],
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.ink),
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

/// Port of `PatientData`'s photo (`img_profile`/`ImagePicker`) and
/// signature (`SilkySignaturePad`/`rbFromGallery`) capture, both optional —
/// the PDF report reserves no space for either when its path is empty
/// (see `PdfReportService`), matching `PdfGenerator`'s own
/// non-empty-string-checked draw calls.
class _PhotoSignatureRow extends StatelessWidget {
  const _PhotoSignatureRow({required this.controller});
  final PatientInfoController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PhotoPicker(controller: controller),
        const SizedBox(width: 14),
        Expanded(child: _SignaturePicker(controller: controller)),
      ],
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({required this.controller});
  final PatientInfoController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Obx(() {
          final path = controller.photoPath.value;
          return GestureDetector(
            onTap: () => _showPhotoActionSheet(context, controller),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    border: Border.all(color: path.isEmpty ? AppColors.placeholder : AppColors.border, width: 1.4),
                    image: path.isEmpty ? null : DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover),
                  ),
                  child: path.isEmpty ? const Icon(Icons.person_outline, color: AppColors.placeholder, size: 26) : null,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(color: AppColors.brandRed, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.8)),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 10.5),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 6),
        const Text('Photo', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.muted2)),
      ],
    );
  }
}

class _SignaturePicker extends StatelessWidget {
  const _SignaturePicker({required this.controller});
  final PatientInfoController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Signature', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
        const SizedBox(height: 5),
        Obx(() {
          final path = controller.signaturePath.value;
          return GestureDetector(
            onTap: () => _showSignatureSheet(context, controller),
            child: Container(
              height: 64,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: path.isEmpty ? AppColors.placeholder : AppColors.border, width: 1.2),
              ),
              child: path.isEmpty
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.draw_outlined, size: 16, color: AppColors.placeholder),
                        SizedBox(width: 6),
                        Text('Tap to add signature', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.muted2)),
                      ],
                    )
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.file(File(path), fit: BoxFit.contain, height: 48),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: controller.clearSignature,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(color: AppColors.brandRedTint, borderRadius: BorderRadius.circular(6)),
                              child: const Text('CLEAR', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.brandRed)),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          );
        }),
      ],
    );
  }
}

void _showPhotoActionSheet(BuildContext context, PatientInfoController controller) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('Patient Photo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            const Text(
              'Take a new photo or choose one from your gallery',
              style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            _SheetAction(
              icon: Icons.photo_camera_outlined,
              label: 'Take Photo',
              onTap: () {
                Navigator.pop(sheetContext);
                controller.pickPhoto(ImageSource.camera);
              },
            ),
            _SheetAction(
              icon: Icons.photo_library_outlined,
              label: 'Choose from Gallery',
              onTap: () {
                Navigator.pop(sheetContext);
                controller.pickPhoto(ImageSource.gallery);
              },
            ),
            Obx(() => controller.photoPath.value.isEmpty
                ? const SizedBox.shrink()
                : _SheetAction(
                    icon: Icons.delete_outline,
                    label: 'Remove Photo',
                    danger: true,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      controller.removePhoto();
                    },
                  )),
          ],
        ),
      ),
    ),
  );
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({required this.icon, required this.label, required this.onTap, this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: danger ? const Color(0xFFFDECEA) : AppColors.brandRedTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: AppColors.brandRed),
            ),
            const SizedBox(width: 11),
            Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: danger ? AppColors.brandRed : AppColors.ink)),
          ],
        ),
      ),
    );
  }
}

void _showSignatureSheet(BuildContext context, PatientInfoController controller) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => _SignaturePadSheet(controller: controller),
  );
}

/// Owns the `signature` package's drawing-pad controller for the sheet's
/// lifetime — port of `PatientData`'s default `SilkySignaturePad` mode,
/// with "Upload instead" as the alternate `rbFromGallery` path.
class _SignaturePadSheet extends StatefulWidget {
  const _SignaturePadSheet({required this.controller});
  final PatientInfoController controller;

  @override
  State<_SignaturePadSheet> createState() => _SignaturePadSheetState();
}

class _SignaturePadSheetState extends State<_SignaturePadSheet> {
  late final SignatureController _padController;

  @override
  void initState() {
    super.initState();
    _padController = SignatureController(penStrokeWidth: 2.4, penColor: AppColors.ink, exportBackgroundColor: Colors.white);
  }

  @override
  void dispose() {
    _padController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_padController.isEmpty) {
      Navigator.pop(context);
      return;
    }
    final bytes = await _padController.toPngBytes();
    if (bytes != null) await widget.controller.saveDrawnSignature(bytes);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Patient Signature', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.controller.pickSignatureFromGallery();
                    },
                    child: const Text('Upload instead', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const Text(
                'Sign with your finger below',
                style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              Container(
                height: 180,
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                clipBehavior: Clip.antiAlias,
                child: Signature(controller: _padController, backgroundColor: AppColors.surface),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _padController.clear(),
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: const Text('Save Signature'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
            Text('Gender', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
          ],
        ),
        const SizedBox(height: 5),
        Obx(() => DropdownButtonFormField<String>(
              initialValue: controller.gender.value,
              hint: const Text('Select gender', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.placeholder)),
              validator: (v) => v == null ? 'Required' : null,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.ink),
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
