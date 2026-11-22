import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/select_field.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../shell/app_shell.dart';
import '../controllers/download_ecg_controller.dart';

class DownloadEcgView extends GetView<DownloadEcgController> {
  const DownloadEcgView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final wide = Responsive.width(context) >= 1100;
    final filters = _FiltersCard(controller: c);
    final export = _ExportCard(controller: c);
    return AppShell(
      active: 'download_ecg',
      title: 'Download ECG',
      child: PageBody(maxWidth: 1320, children: [
        const PageHeader(
          breadcrumb: 'Clinical / Download ECG',
          title: 'Export centre',
          subtitle: 'Filter the data, then export ECG records as a zip of PDFs or as CSV files.',
        ),
        if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 3, child: filters),
            const SizedBox(width: 20),
            Expanded(flex: 2, child: export),
          ])
        else ...[filters, export],
      ]),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.n, this.title);
  final int n;
  final String title;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle),
          child: Text('$n', style: AppTextStyles.body(weight: FontWeight.w700, color: Colors.white)),
        ),
        const SizedBox(width: 10),
        Text(title, style: AppTextStyles.h2),
      ]);
}

class _FiltersCard extends StatelessWidget {
  const _FiltersCard({required this.controller});
  final DownloadEcgController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Obx(() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Step(1, 'Choose records'),
            const SizedBox(height: 22),
            LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth > 520 ? (box.maxWidth - 16) / 2 : box.maxWidth;
              return Wrap(spacing: 16, runSpacing: 16, children: [
                SizedBox(width: w, child: LookupField(label: 'Hospital', value: c.hospital.value, hint: 'All hospitals', onTap: c.pickHospital)),
                SizedBox(
                  width: w,
                  child: LookupField(
                    label: 'Staff',
                    value: c.staff.value,
                    hint: c.hospital.value == null ? 'All staff (choose a hospital first)' : 'All staff',
                    onTap: c.pickStaff,
                  ),
                ),
              ]);
            }),
            const SizedBox(height: 22),
            Text('Date', style: AppTextStyles.label),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _pill('Any date', c.datePreset.value == null, () => c.setPreset(context, null)),
              for (final p in DatePreset.values)
                _pill(
                  p == DatePreset.custom && c.datePreset.value == DatePreset.custom && c.fromDate.value != null
                      ? '${Fmt.date(c.fromDate.value)} – ${Fmt.date(c.toDate.value)}'
                      : p.label,
                  c.datePreset.value == p,
                  () => c.setPreset(context, p),
                ),
            ]),
            const SizedBox(height: 22),
            Text('ECG status', style: AppTextStyles.label),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: AppColors.ground, borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _seg('All', c.ecgStatus.value == null, () => c.setEcgStatus(null)),
                _seg('Normal', c.ecgStatus.value == 'normal', () => c.setEcgStatus('normal')),
                _seg('Abnormal', c.ecgStatus.value == 'abnormal', () => c.setEcgStatus('abnormal')),
              ]),
            ),
          ])),
    );
  }

  Widget _pill(String label, bool active, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: active ? AppColors.brand : Colors.white,
            border: Border.all(color: active ? AppColors.brand : AppColors.field),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(label, style: AppTextStyles.body(size: 13, weight: FontWeight.w600, color: active ? Colors.white : AppColors.body)),
        ),
      );

  Widget _seg(String label, bool active, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active ? const [BoxShadow(color: Color(0x14101828), blurRadius: 3, offset: Offset(0, 1))] : null,
          ),
          child: Text(label, style: AppTextStyles.body(weight: FontWeight.w600, color: active ? AppColors.ink : AppColors.muted)),
        ),
      );
}

class _ExportCard extends StatelessWidget {
  const _ExportCard({required this.controller});
  final DownloadEcgController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppCard(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const _Step(2, 'Export'),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
            child: Obx(() => Row(children: [
                  c.counting.value
                      ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.4))
                      : CountUpText(c.count.value ?? 0, style: AppTextStyles.display(28)),
                  const SizedBox(width: 12),
                  Expanded(child: Text('records match these filters', style: AppTextStyles.body(color: AppColors.muted))),
                ])),
          ),
          const SizedBox(height: 14),
          Obx(() => _ExportOption(
                title: 'Export ECG PDF',
                subtitle: 'ECG, cardiologist report and merged report PDFs in one .zip',
                icon: Icons.picture_as_pdf_outlined,
                primary: true,
                loading: c.exporting.value == 'pdf',
                enabled: c.exporting.value == null && (c.count.value ?? 0) > 0,
                onTap: () => c.export('pdf'),
              )),
          const SizedBox(height: 10),
          Obx(() => _ExportOption(
                title: 'Export CSV',
                subtitle: 'The raw CSV file of each recording, zipped',
                icon: Icons.table_chart_outlined,
                loading: c.exporting.value == 'csv',
                enabled: c.exporting.value == null && (c.count.value ?? 0) > 0,
                onTap: () => c.export('csv'),
              )),
          const SizedBox(height: 10),
          Text('Large exports can take a minute — keep this page open until the download starts.', style: AppTextStyles.caption),
        ]),
      ),
      const SizedBox(height: 16),
      Obx(() => c.recent.isEmpty
          ? const SizedBox.shrink()
          : AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SectionTitle('Exported this session'),
                const SizedBox(height: 10),
                for (final r in c.recent)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      const Icon(Icons.inventory_2_outlined, size: 20, color: AppColors.subtle),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.name, style: AppTextStyles.body(weight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                          Text('${r.detail} · ${Fmt.ago(r.at)}', style: AppTextStyles.caption),
                        ]),
                      ),
                    ]),
                  ).animate().fadeIn(),
              ]),
            )),
    ]);
  }
}

class _ExportOption extends StatelessWidget {
  const _ExportOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.primary = false,
    this.loading = false,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  final bool loading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final accent = primary ? AppColors.brand : AppColors.green;
    return Opacity(
      opacity: enabled || loading ? 1 : .55,
      child: Material(
        color: primary ? AppColors.brandTint : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: primary ? AppColors.brandSoft : AppColors.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: primary ? AppColors.brand : AppColors.greenTint, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: primary ? Colors.white : AppColors.green),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: AppTextStyles.body(size: 15, weight: FontWeight.w700)),
                  Text(subtitle, style: AppTextStyles.body(size: 13, color: AppColors.muted)),
                ]),
              ),
              loading
                  ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: accent))
                  : Icon(Icons.download_rounded, color: accent),
            ]),
          ),
        ),
      ),
    );
  }
}
