import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/utils/link_opener.dart';
import '../../../core/utils/navigation.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/form_fields.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/pdf_preview/pdf_preview.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../shell/app_shell.dart';
import '../controllers/diagnose_controller.dart';

class DiagnoseView extends GetView<DiagnoseController> {
  const DiagnoseView({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await controller.confirmLeave()) closeRoute(null, AppRoutes.ecgRecords);
      },
      child: AppShell(
        active: 'ecg_records',
        title: 'Cardiologist report',
        child: Obx(() {
          final rec = controller.record.value;
          if (controller.loading.value) return const Center(child: CircularProgressIndicator());
          if (rec == null) return ErrorState(message: controller.error.value ?? 'ECG not found.', onRetry: controller.load);

          final wide = Responsive.width(context) >= 1240;
          final preview = AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text('ECG recording', style: AppTextStyles.h3)),
                TextButton.icon(
                  onPressed: () => LinkOpener.open(rec.ecgPdfUrl),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Open'),
                ),
              ]),
              const SizedBox(height: 10),
              PdfPreview(url: rec.ecgPdfUrl, height: wide ? 760 : 460),
            ]),
          );
          final form = _ReportForm(controller: controller);

          return PageBody(children: [
            PageHeader(
              breadcrumb: 'ECG Records / Diagnose',
              title: rec.displayName,
              subtitle: '${rec.hospitalName ?? ''} · ${rec.staffName ?? ''} · ${rec.fileName}',
              actions: [
                Obx(() => SecondaryButton(
                      label: controller.saving.value == 'draft' ? 'Saving…' : 'Save draft',
                      icon: Icons.save_outlined,
                      onPressed: controller.saving.value != null ? null : () => controller.save(publish: false),
                    )),
                Obx(() => PrimaryButton(
                      label: 'Publish report',
                      icon: Icons.verified_outlined,
                      loading: controller.saving.value == 'publish',
                      onPressed: controller.saving.value != null ? null : () => controller.save(publish: true),
                    )),
              ],
            ),
            if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 5, child: preview),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: form),
              ])
            else ...[form, preview],
          ]);
        }),
      ),
    );
  }
}

class _ReportForm extends StatelessWidget {
  const _ReportForm({required this.controller});
  final DiagnoseController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text.rich(TextSpan(children: [
            TextSpan(text: 'ECG status', style: AppTextStyles.h3),
            TextSpan(text: ' *', style: AppTextStyles.h3.copyWith(color: AppColors.dangerText)),
          ])),
          const SizedBox(height: 12),
          Obx(() => Row(children: [
                Expanded(child: _StatusChoice(label: 'Normal', icon: Icons.check_circle_outline_rounded, color: AppColors.success, selected: c.ecgStatus.value == 'normal', onTap: () => c.setEcgStatus('normal'))),
                const SizedBox(width: 10),
                Expanded(child: _StatusChoice(label: 'Abnormal', icon: Icons.error_outline_rounded, color: AppColors.danger, selected: c.ecgStatus.value == 'abnormal', onTap: () => c.setEcgStatus('abnormal'))),
              ])),
          Obx(() => c.ecgStatusError.value == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(c.ecgStatusError.value!, style: AppTextStyles.body(size: 12.5, color: AppColors.dangerText)),
                )),
        ]),
      ),
      const SizedBox(height: 16),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('Doctor\'s advice', style: AppTextStyles.h3)),
            Obx(() => c.templates.isEmpty
                ? const SizedBox.shrink()
                : PopupMenuButton(
                    tooltip: 'Insert a template',
                    onSelected: c.applyTemplate,
                    itemBuilder: (_) => [for (final t in c.templates) PopupMenuItem(value: t, child: Text(t.title))],
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.description_outlined, size: 18, color: AppColors.brand),
                        SizedBox(width: 6),
                        Text('Templates', style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  )),
          ]),
          const SizedBox(height: 4),
          Text('One paragraph per line. Start a line with "-" or "•" for a bullet point.', style: AppTextStyles.caption),
          const SizedBox(height: 12),
          TextField(
            controller: c.advice,
            minLines: 8,
            maxLines: 16,
            style: AppTextStyles.body(size: 15, height: 1.55),
            decoration: const InputDecoration(hintText: 'e.g. Sinus rhythm. No acute ST-T changes.\n- Correlate clinically'),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Measurements', style: AppTextStyles.h3),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, box) {
            final cols = box.maxWidth > 460 ? 4 : 2;
            final w = (box.maxWidth - (cols - 1) * 12) / cols;
            final fields = [
              ('HR', c.hr, 'bpm'),
              ('R (II)', c.r, 'mV'),
              ('RR', c.rr, 'ms'),
              ('PR', c.pr, 'ms'),
              ('QRS', c.qrs, 'ms'),
              ('QT', c.qt, 'ms'),
              ('QTc', c.qtc, 'ms'),
            ];
            return Wrap(spacing: 12, runSpacing: 14, children: [
              for (final f in fields)
                SizedBox(
                  width: w,
                  child: AppTextField(
                    label: '${f.$1} (${f.$3})',
                    controller: f.$2,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  ),
                ),
              SizedBox(
                width: w,
                child: AppTextField(label: 'QT/QTc', controller: c.qtByQtc, readOnly: true, helper: 'Calculated'),
              ),
            ]);
          }),
        ]),
      ),
    ]);
  }
}

class _StatusChoice extends StatelessWidget {
  const _StatusChoice({required this.label, required this.icon, required this.color, required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: .08) : Colors.white,
            border: Border.all(color: selected ? color : AppColors.field, width: selected ? 1.6 : 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(icon, color: selected ? color : AppColors.subtle),
            const SizedBox(width: 10),
            Text(label, style: AppTextStyles.body(size: 15, weight: FontWeight.w600, color: selected ? color : AppColors.body)),
            const Spacer(),
            AnimatedScale(
              scale: selected ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.check_rounded, color: color, size: 18),
            ),
          ]),
        ),
      ),
    );
  }
}
