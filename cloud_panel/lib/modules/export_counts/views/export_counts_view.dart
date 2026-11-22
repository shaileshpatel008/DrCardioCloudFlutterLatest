import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../shell/app_shell.dart';
import '../controllers/export_counts_controller.dart';

class ExportCountsView extends GetView<ExportCountsController> {
  const ExportCountsView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return AppShell(
      active: 'export_ecg_counts',
      title: 'Export ECG Counts',
      child: PageBody(maxWidth: 760, children: [
        const PageHeader(
          breadcrumb: 'Clinical / Export ECG Counts',
          title: 'Export ECG counts',
          subtitle: 'Download a CSV of every ECG assigned to you in a month — hospital, patient name, age, gender, patient ID and report date.',
        ),
        AppCard(
          padding: const EdgeInsets.all(24),
          child: Obx(() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Month', style: AppTextStyles.label),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (var m = 1; m <= 12; m++)
                    ChoiceChip(
                      label: Text(AppConstants.months[m - 1].substring(0, 3)),
                      selected: c.month.value == m,
                      onSelected: (_) => c.month.value = m,
                      selectedColor: AppColors.brand,
                      labelStyle: AppTextStyles.body(size: 13, weight: FontWeight.w600, color: c.month.value == m ? Colors.white : AppColors.body),
                      showCheckmark: false,
                    ),
                ]),
                const SizedBox(height: 22),
                Text('Year', style: AppTextStyles.label),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final y in c.years)
                    ChoiceChip(
                      label: Text('$y'),
                      selected: c.year.value == y,
                      onSelected: (_) => c.year.value = y,
                      selectedColor: AppColors.brand,
                      labelStyle: AppTextStyles.body(size: 13, weight: FontWeight.w600, color: c.year.value == y ? Colors.white : AppColors.body),
                      showCheckmark: false,
                    ),
                ]),
                const SizedBox(height: 26),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.table_chart_outlined, color: AppColors.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('ECG_Counts_${c.monthLabel}_${c.year.value}.csv', style: AppTextStyles.body(weight: FontWeight.w600)),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Export CSV',
                  icon: Icons.download_rounded,
                  loading: c.exporting.value,
                  onPressed: c.export,
                  expand: true,
                ),
              ])),
        ),
      ]),
    );
  }
}
