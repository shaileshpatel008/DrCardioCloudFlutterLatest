import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/html_text.dart';
import '../../../core/utils/link_opener.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/pdf_preview/pdf_preview.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/models/ecg_record_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../shell/app_shell.dart';
import '../controllers/ecg_detail_controller.dart';

class EcgDetailView extends GetView<EcgDetailController> {
  const EcgDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      active: 'ecg_records',
      title: 'ECG record',
      child: Obx(() {
        final r = controller.record.value;
        if (controller.loading.value && r == null) return const Center(child: CircularProgressIndicator());
        if (r == null) {
          return ErrorState(message: controller.error.value ?? 'ECG record not found.', onRetry: controller.load);
        }
        final wide = Responsive.width(context) >= 1240;
        final left = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Documents(controller: controller, record: r),
          const SizedBox(height: 16),
          if (r.cardiologistReport != null) _ReportText(record: r),
        ]);
        final right = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Details(record: r),
          const SizedBox(height: 16),
          if (r.patient != null && !r.patient!.isEmpty) ...[_Patient(record: r), const SizedBox(height: 16)],
          _Measurements(record: r),
        ]);

        return PageBody(
          onRefresh: controller.load,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Get.previousRoute.isEmpty ? Get.offAllNamed(AppRoutes.ecgRecords) : Get.back(),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('All ECG records'),
              ),
            ),
            _Header(controller: controller, record: r),
            if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 3, child: left),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: right),
              ])
            else ...[left, right],
          ],
        );
      }),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.record});
  final EcgDetailController controller;
  final EcgRecord record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final a = r.actions;
    final steps = <(String, String, bool, bool)>[
      ('Recorded', [r.staffName, Fmt.time(r.createdAt)].whereType<String>().where((s) => s.isNotEmpty).join(' · '), true, false),
      ('Uploaded', [Fmt.dateTime(r.updatedAt)].join(), true, false),
      (
        'Requested',
        r.requestedAt == null ? 'Not sent for report' : '${Fmt.time(r.requestedAt)} · ${r.cardiologistName ?? ''}',
        r.status == ReportStatus.requested || r.status == ReportStatus.reported,
        false
      ),
      (
        'Reported',
        r.reportedAt == null ? 'Awaiting report' : '${Fmt.time(r.reportedAt)} · TAT ${Fmt.minutes(r.tatMinutes)}',
        r.status == ReportStatus.reported,
        r.status == ReportStatus.reported
      ),
    ];

    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(alignment: WrapAlignment.spaceBetween, runSpacing: 14, spacing: 16, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(r.displayName, style: AppTextStyles.display(26)),
              StatusBadge(status: r.status, label: r.statusLabel),
              EcgTag(r.ecgStatus),
              if (r.isReassigned)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.lineSoft, borderRadius: BorderRadius.circular(999)),
                  child: Text('Re-assigned', style: AppTextStyles.body(size: 12, weight: FontWeight.w600, color: AppColors.muted)),
                ),
            ]),
            const SizedBox(height: 6),
            Text('${r.fileName} · Uploaded ${Fmt.dateTime(r.updatedAt)}', style: AppTextStyles.muted),
          ]),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (a.diagnose) PrimaryButton(label: 'Diagnose', icon: Icons.edit_note_rounded, onPressed: controller.diagnose),
            if (a.editReport) SecondaryButton(label: 'Edit report', icon: Icons.edit_note_rounded, onPressed: controller.diagnose),
            if (a.reassign) SecondaryButton(label: 'Re-assign', icon: Icons.swap_horiz_rounded, onPressed: controller.reassign),
            if (a.assign) SecondaryButton(label: 'Send for report', icon: Icons.send_rounded, onPressed: controller.assign),
            if (a.delete) SecondaryButton(label: 'Delete', icon: Icons.delete_outline_rounded, danger: true, onPressed: controller.delete),
          ]),
        ]),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, box) {
          final cols = box.maxWidth > 760 ? 4 : 2;
          final w = (box.maxWidth - (cols - 1) * 10) / cols;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            for (var i = 0; i < steps.length; i++)
              SizedBox(
                width: w,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: steps[i].$4 ? AppColors.successBg : AppColors.surfaceAlt,
                    border: Border.all(color: steps[i].$4 ? const Color(0xFFBBF7D0) : Colors.transparent),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(color: steps[i].$3 ? AppColors.success : AppColors.field, shape: BoxShape.circle),
                        child: Icon(steps[i].$3 ? Icons.check_rounded : Icons.more_horiz_rounded, size: 13, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Text(steps[i].$1, style: AppTextStyles.body(size: 13, weight: FontWeight.w600, color: steps[i].$4 ? AppColors.reportedText : AppColors.ink)),
                    ]),
                    const SizedBox(height: 5),
                    Text(steps[i].$2, style: AppTextStyles.body(size: 12, color: AppColors.muted), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ]),
                ).animate().fadeIn(delay: (120 * i).ms, duration: 300.ms).slideX(begin: -.05, end: 0),
              ),
          ]);
        }),
      ]),
    );
  }
}

class _Documents extends StatelessWidget {
  const _Documents({required this.controller, required this.record});
  final EcgDetailController controller;
  final EcgRecord record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    return Obx(() {
      final tab = r.reportPdfUrl == null ? 0 : controller.docTab.value;
      final url = tab == 0 ? r.ecgPdfUrl : r.reportPdfUrl;
      return AppCard(
        padding: EdgeInsets.zero,
        clip: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Wrap(alignment: WrapAlignment.spaceBetween, runSpacing: 10, spacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: AppColors.ground, borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _segment('ECG recording', tab == 0, () => controller.docTab.value = 0),
                  if (r.reportPdfUrl != null) _segment('Cardiologist report', tab == 1, () => controller.docTab.value = 1),
                ]),
              ),
              Wrap(spacing: 8, runSpacing: 8, children: [
                SecondaryButton(label: 'Open / download', icon: Icons.open_in_new_rounded, onPressed: () => LinkOpener.open(url)),
                if (r.csvUrl != null) SecondaryButton(label: 'CSV data', icon: Icons.table_chart_outlined, onPressed: () => LinkOpener.open(r.csvUrl)),
              ]),
            ]),
          ),
          const Divider(),
          Container(
            color: const Color(0xFFFBF7F6),
            padding: const EdgeInsets.all(14),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: PdfPreview(
                key: ValueKey(url),
                url: url,
                height: Responsive.isPhone(context) ? 420 : 620,
                title: tab == 0 ? 'ECG recording' : 'Cardiologist report',
              ),
            ),
          ),
        ]),
      );
    });
  }

  Widget _segment(String label, bool active, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: active ? const [BoxShadow(color: Color(0x14101828), blurRadius: 3, offset: Offset(0, 1))] : null,
          ),
          child: Text(label, style: AppTextStyles.body(size: 13, weight: FontWeight.w600, color: active ? AppColors.ink : AppColors.muted)),
        ),
      );
}

class _Details extends StatelessWidget {
  const _Details({required this.record});
  final EcgRecord record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('Record details'),
        const SizedBox(height: 16),
        _grid([
          InfoTile(label: 'Staff', value: r.staffName),
          InfoTile(
            label: 'Hospital',
            child: r.clientUserId == null || !(Get.find<EcgDetailController>().user?.can('clients') ?? false)
                ? Text(r.hospitalName ?? '—', style: AppTextStyles.body(weight: FontWeight.w600))
                : InkWell(
                    onTap: () => Get.toNamed(AppRoutes.clientPath(r.clientUserId!)),
                    child: Text(r.hospitalName ?? '—', style: AppTextStyles.body(weight: FontWeight.w600, color: AppColors.brand)),
                  ),
          ),
          InfoTile(label: 'Doctor', value: r.doctorName),
          InfoTile(label: 'Cardiologist', value: r.cardiologistName),
          InfoTile(label: 'Device ID', value: r.instrumentId, mono: true),
          InfoTile(label: 'Mobile', value: r.deviceModel),
          InfoTile(label: 'Date & time', value: Fmt.dateTime(r.updatedAt)),
          InfoTile(
            label: 'Live location',
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.place_outlined, size: 16, color: AppColors.brand)),
              const SizedBox(width: 4),
              Expanded(
                child: r.hasLocation
                    ? InkWell(
                        onTap: () => LinkOpener.map(r.latitude!, r.longitude!),
                        child: Text(r.address ?? '${r.latitude}, ${r.longitude}',
                            style: AppTextStyles.body(weight: FontWeight.w600, color: AppColors.brand)),
                      )
                    : Text(r.address ?? 'Not captured', style: AppTextStyles.body(weight: FontWeight.w600)),
              ),
            ]),
          ),
        ]),
      ]),
    );
  }
}

class _Patient extends StatelessWidget {
  const _Patient({required this.record});
  final EcgRecord record;

  @override
  Widget build(BuildContext context) {
    final p = record.patient!;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('Patient'),
        const SizedBox(height: 16),
        _grid([
          InfoTile(label: 'Name', value: p.name),
          InfoTile(label: 'Patient ID', value: p.id),
          InfoTile(label: 'Age', value: p.age),
          InfoTile(label: 'Gender', value: p.gender),
        ]),
      ]),
    );
  }
}

class _Measurements extends StatelessWidget {
  const _Measurements({required this.record});
  final EcgRecord record;

  @override
  Widget build(BuildContext context) {
    final m = record.measurements;
    final items = [
      ('HR', m.hr, 'bpm'),
      ('PR', m.pr, 'ms'),
      ('QRS', m.qrs, 'ms'),
      ('QT', m.qt, 'ms'),
      ('QTc', m.qtc, 'ms'),
      ('QT/QTc', m.qtByQtc, ''),
      ('RR', m.rr, 'ms'),
      ('R (II)', m.r, 'mV'),
    ];
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [SectionTitle('Measurements'), SizedBox(width: 10), NewTag()]),
        const SizedBox(height: 14),
        if (m.isEmpty)
          Text('Measurements are added by the cardiologist when the report is written.', style: AppTextStyles.muted)
        else
          LayoutBuilder(builder: (context, box) {
            final cols = box.maxWidth > 420 ? 4 : 2;
            final w = (box.maxWidth - (cols - 1) * 10) / cols;
            return Wrap(spacing: 10, runSpacing: 10, children: [
              for (final i in items)
                SizedBox(
                  width: w,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(i.$1, style: AppTextStyles.caption),
                      Text.rich(TextSpan(children: [
                        TextSpan(text: i.$2 ?? '—', style: AppTextStyles.body(size: 18, weight: FontWeight.w700)),
                        if (i.$2 != null && i.$3.isNotEmpty) TextSpan(text: ' ${i.$3}', style: AppTextStyles.caption),
                      ])),
                    ]),
                  ),
                ),
            ]);
          }),
      ]),
    );
  }
}

class _ReportText extends StatelessWidget {
  const _ReportText({required this.record});
  final EcgRecord record;

  @override
  Widget build(BuildContext context) {
    final text = HtmlText.toPlain(record.cardiologistReport);
    if (text.isEmpty) return const SizedBox.shrink();
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionTitle('Doctor\'s advice', subtitle: record.cardiologistName == null ? null : 'by ${record.cardiologistName}'),
        const SizedBox(height: 12),
        SelectableText(text, style: AppTextStyles.body(size: 15, height: 1.6)),
      ]),
    );
  }
}

Widget _grid(List<Widget> tiles) => LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth > 520 ? 2 : 1;
      final w = (box.maxWidth - (cols - 1) * 24) / cols;
      return Wrap(spacing: 24, runSpacing: 18, children: [for (final t in tiles) SizedBox(width: w, child: t)]);
    });
