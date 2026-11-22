import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/models/dashboard_model.dart';
import '../../../data/models/ecg_record_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../shell/app_shell.dart';
import '../controllers/dashboard_controller.dart';

class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      active: 'dashboard',
      title: 'Dashboard',
      child: Obx(() {
        final d = controller.data.value;
        final user = controller.user;
        if (controller.loading.value && d == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (d == null) {
          return ErrorState(message: controller.error.value ?? 'Couldn\'t load the dashboard.', onRetry: controller.load);
        }
        return PageBody(
          onRefresh: controller.load,
          children: [
            PageHeader(
              breadcrumb: DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
              title: '${Fmt.greeting()}, ${user?.name ?? ''}',
              subtitle: user?.isCardiologist == true
                  ? 'Here are the ECGs waiting for your report.'
                  : 'Here\'s what is happening across your ECG network.',
              actions: _actions(),
            ),
            _Tiles(data: d),
            _InsightsRow(data: d),
            _RecentRow(data: d),
          ],
        );
      }),
    );
  }

  List<Widget> _actions() {
    final u = controller.user;
    if (u == null) return const [];
    return [
      if (u.can('download_ecg'))
        SecondaryButton(label: 'Export ECG', icon: Icons.download_rounded, onPressed: () => Get.offAllNamed(AppRoutes.downloadEcg)),
      if (u.can('devices'))
        SecondaryButton(label: 'Add device', icon: Icons.add_rounded, onPressed: () => Get.offAllNamed(AppRoutes.devices, parameters: {'add': '1'})),
      if (u.can('clients'))
        PrimaryButton(label: 'Add client', icon: Icons.add_rounded, onPressed: () => Get.toNamed(AppRoutes.clientNew)),
      if (u.can('client_staffs'))
        PrimaryButton(label: 'Add staff', icon: Icons.person_add_alt_rounded, onPressed: () => Get.offAllNamed(AppRoutes.myStaff, parameters: {'add': '1'})),
      if (u.isCardiologist)
        PrimaryButton(
          label: 'Review requested ECGs',
          icon: Icons.fact_check_outlined,
          onPressed: () => Get.offAllNamed(AppRoutes.ecgRecords, parameters: {'status': 'requested'}),
        ),
    ];
  }
}

class _Tiles extends StatelessWidget {
  const _Tiles({required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final c = data.counts;
    final defs = <String, (String, int, IconData, Color, Color, String, String)>{
      'ecg_records': ('ECG Records', c.ecgRecords, Icons.monitor_heart_outlined, AppColors.brand, Colors.white, 'View all records', AppRoutes.ecgRecords),
      'clients': ('Clients', c.clients, Icons.apartment_rounded, AppColors.blueTint, AppColors.blue, 'Hospitals & labs', AppRoutes.clients),
      'devices': ('Devices', c.devices, Icons.developer_board_rounded, AppColors.greenTint, AppColors.green, 'Registered devices', AppRoutes.devices),
      'cardiologists': ('Cardiologists', c.cardiologists, Icons.favorite_border_rounded, AppColors.brandTint, AppColors.brand, 'Reporting panel', AppRoutes.cardiologists),
      'staffs': ('Staff', c.staffs, Icons.groups_2_outlined, AppColors.violetTint, AppColors.violet, 'Technicians', ''),
      'normal_ecg': ('Normal ECG', c.normalEcg, Icons.check_circle_outline_rounded, AppColors.greenTint, AppColors.green, 'Reported normal', AppRoutes.ecgRecords),
      'abnormal_ecg': ('Abnormal ECG', c.abnormalEcg, Icons.error_outline_rounded, AppColors.dangerBg, AppColors.dangerText, 'Reported abnormal', AppRoutes.ecgRecords),
    };
    final u = Get.find<DashboardController>().user;
    final staffRoute = (u?.can('admin_staffs') ?? false) ? AppRoutes.adminStaffs : AppRoutes.myStaff;

    return LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth >= 1100 ? 5 : box.maxWidth >= 760 ? 3 : 2;
      final w = (box.maxWidth - (cols - 1) * 16) / cols;
      return Wrap(spacing: 16, runSpacing: 16, children: [
        for (var i = 0; i < data.tiles.length; i++)
          if (defs.containsKey(data.tiles[i]))
            SizedBox(
              width: w,
              child: _KpiTile(
                label: defs[data.tiles[i]]!.$1,
                value: defs[data.tiles[i]]!.$2,
                icon: defs[data.tiles[i]]!.$3,
                tint: defs[data.tiles[i]]!.$4,
                iconColor: defs[data.tiles[i]]!.$5,
                link: defs[data.tiles[i]]!.$6,
                hero: i == 0,
                onTap: () {
                  final key = data.tiles[i];
                  final route = key == 'staffs' ? staffRoute : defs[key]!.$7;
                  final params = switch (key) {
                    'normal_ecg' => {'ecg_status': 'normal'},
                    'abnormal_ecg' => {'ecg_status': 'abnormal'},
                    _ => <String, String>{},
                  };
                  if (route.isNotEmpty) Get.offAllNamed(route, parameters: params);
                },
              ).animate().fadeIn(duration: 350.ms, delay: (70 * i).ms).slideY(begin: .12, end: 0, curve: Curves.easeOutCubic),
            ),
      ]);
    });
  }
}

class _KpiTile extends StatefulWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.link,
    required this.onTap,
    this.hero = false,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color tint;
  final Color iconColor;
  final String link;
  final VoidCallback onTap;
  final bool hero;

  @override
  State<_KpiTile> createState() => _KpiTileState();
}

class _KpiTileState extends State<_KpiTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final hero = widget.hero;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: hero ? AppColors.brand : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: hero ? AppColors.brand : (_hover ? AppColors.brandSoft : AppColors.line)),
            boxShadow: [
              BoxShadow(
                color: hero ? AppColors.brand.withValues(alpha: _hover ? .35 : .2) : Colors.black.withValues(alpha: _hover ? .07 : .02),
                blurRadius: _hover ? 26 : 10,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(widget.label,
                    style: AppTextStyles.body(weight: FontWeight.w600, color: hero ? const Color(0xFFFFE4DF) : AppColors.muted)),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: hero ? Colors.white.withValues(alpha: .16) : widget.tint,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(widget.icon, size: 20, color: widget.iconColor),
              ),
            ]),
            const SizedBox(height: 14),
            CountUpText(widget.value, style: AppTextStyles.display(32, color: hero ? Colors.white : AppColors.ink)),
            const SizedBox(height: 10),
            Text('${widget.link} →',
                style: AppTextStyles.body(size: 13, weight: FontWeight.w600, color: hero ? const Color(0xFFFFE4DF) : AppColors.brand)),
          ]),
        ),
      ),
    );
  }
}

class _InsightsRow extends StatelessWidget {
  const _InsightsRow({required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final chart = _VolumeChart(insights: data.insights);
    final mix = _StatusMix(insights: data.insights);
    if (Responsive.width(context) < 1100) {
      return Column(children: [chart, const SizedBox(height: 16), mix]);
    }
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(flex: 2, child: chart),
        const SizedBox(width: 16),
        Expanded(child: mix),
      ]),
    );
  }
}

class _VolumeChart extends StatefulWidget {
  const _VolumeChart({required this.insights});
  final DashboardInsights insights;

  @override
  State<_VolumeChart> createState() => _VolumeChartState();
}

class _VolumeChartState extends State<_VolumeChart> {
  int? _hover;

  @override
  Widget build(BuildContext context) {
    final days = widget.insights.daily;
    final maxV = days.fold<int>(0, (m, d) => d.total > m ? d.total : m);
    final top = maxV == 0 ? 10 : ((maxV / 4).ceil() * 4);
    final busiest = days.isEmpty ? null : days.reduce((a, b) => b.total > a.total ? b : a);
    final total = widget.insights.dailyTotal;

    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('ECGs recorded per day', style: AppTextStyles.h3),
          const SizedBox(width: 10),
          const NewTag(),
          const Spacer(),
          Text('Last 14 days', style: AppTextStyles.caption),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 28, runSpacing: 10, children: [
          _stat('Last 14 days', Fmt.number(total)),
          _stat('Daily average', Fmt.number(days.isEmpty ? 0 : (total / days.length).round())),
          _stat('Busiest day', busiest == null || busiest.total == 0 ? '—' : DateFormat('d MMM').format(busiest.date)),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          height: 210,
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 34,
              child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(Fmt.number(top), style: AppTextStyles.caption),
                Text(Fmt.number(top ~/ 2), style: AppTextStyles.caption),
                Padding(padding: const EdgeInsets.only(bottom: 20), child: Text('0', style: AppTextStyles.caption)),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LayoutBuilder(builder: (context, box) {
                return Column(children: [
                  Expanded(
                    child: Stack(children: [
                      Positioned.fill(
                        child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
                          Divider(height: 1, color: Color(0xFFEAECF0)),
                          Divider(height: 1, color: Color(0xFFEAECF0)),
                          Divider(height: 1, color: AppColors.field),
                        ]),
                      ),
                      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        for (var i = 0; i < days.length; i++)
                          Expanded(
                            child: MouseRegion(
                              onEnter: (_) => setState(() => _hover = i),
                              onExit: (_) => setState(() => _hover = null),
                              child: Tooltip(
                                message: '${DateFormat('d MMM').format(days[i].date)} · ${Fmt.number(days[i].total)} ECGs',
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 3),
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: top == 0 ? 0 : days[i].total / top),
                                    duration: Duration(milliseconds: 600 + i * 40),
                                    curve: Curves.easeOutCubic,
                                    builder: (_, v, _) => Align(
                                      alignment: Alignment.bottomCenter,
                                      child: FractionallySizedBox(
                                        heightFactor: v.clamp(0.0, 1.0),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 150),
                                          decoration: BoxDecoration(
                                            color: _hover == i ? AppColors.brandDark : AppColors.brand,
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    for (final d in days)
                      Expanded(
                        child: Text(
                          box.maxWidth > 420 ? '${d.date.day}' : (d.date.day % 2 == 0 ? '${d.date.day}' : ''),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(fontSize: 11),
                        ),
                      ),
                  ]),
                ]);
              }),
            ),
          ]),
        ),
      ]),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _stat(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTextStyles.caption),
        Text(value, style: AppTextStyles.display(22)),
      ]);
}

class _StatusMix extends StatelessWidget {
  const _StatusMix({required this.insights});
  final DashboardInsights insights;

  @override
  Widget build(BuildContext context) {
    final total = insights.monthTotal;
    final rows = [
      (ReportStatus.reported, 'Reported', insights.monthReported, AppColors.reported),
      (ReportStatus.pending, 'Pending', insights.monthPending, AppColors.pending),
      (ReportStatus.requested, 'Requested', insights.monthRequested, AppColors.requested),
      (ReportStatus.noCredit, 'No credit', insights.monthNoCredit, AppColors.faint),
    ];
    final ecgTotal = insights.monthNormal + insights.monthAbnormal;
    final abnormalPct = ecgTotal == 0 ? null : (insights.monthAbnormal * 100 / ecgTotal).round();

    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Flexible(child: Text('Report status · this month', style: AppTextStyles.h3)),
          const SizedBox(width: 10),
          const NewTag(),
        ]),
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 14,
            child: total == 0
                ? Container(color: AppColors.lineSoft)
                : Row(children: [
                    for (final r in rows)
                      if (r.$3 > 0)
                        Expanded(
                          flex: r.$3,
                          child: Container(
                            margin: const EdgeInsets.only(right: 2),
                            color: r.$4,
                          ).animate().scaleX(begin: 0, end: 1, alignment: Alignment.centerLeft, duration: 700.ms, curve: Curves.easeOutCubic),
                        ),
                  ]),
          ),
        ),
        const SizedBox(height: 10),
        for (final r in rows)
          InkWell(
            onTap: () => Get.offAllNamed(AppRoutes.ecgRecords, parameters: {'status': r.$1.apiValue}),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: r.$4, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 10),
                Expanded(child: Text(r.$2, style: AppTextStyles.body())),
                Text(Fmt.number(r.$3), style: AppTextStyles.body(weight: FontWeight.w700)),
                SizedBox(
                  width: 48,
                  child: Text(total == 0 ? '—' : '${(r.$3 * 100 / total).round()}%',
                      textAlign: TextAlign.right, style: AppTextStyles.body(color: AppColors.subtle)),
                ),
              ]),
            ),
          ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _mini('Avg. turnaround', Fmt.minutes(insights.avgTatMinutes))),
          const SizedBox(width: 10),
          Expanded(child: _mini('Abnormal ECGs', abnormalPct == null ? '—' : '$abnormalPct%')),
        ]),
      ]),
    ).animate().fadeIn(duration: 400.ms, delay: 260.ms);
  }

  Widget _mini(String label, String value) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 2),
          Text(value, style: AppTextStyles.display(20)),
        ]),
      );
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 14, 12),
          child: Row(children: [
            Text('Latest ECG records', style: AppTextStyles.h3),
            const SizedBox(width: 10),
            const NewTag(),
            const Spacer(),
            TextButton(onPressed: () => Get.offAllNamed(AppRoutes.ecgRecords), child: const Text('View all')),
          ]),
        ),
        if (data.recent.isEmpty)
          const EmptyState(title: 'No ECGs yet', message: 'Recordings uploaded from Dr. Cardio devices will appear here.')
        else
          for (var i = 0; i < data.recent.length; i++)
            InkWell(
              onTap: () => Get.toNamed(AppRoutes.ecgDetailPath(data.recent[i].id)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.lineSoft))),
                child: Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(9)),
                    child: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: AppColors.brand),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(data.recent[i].displayName, style: AppTextStyles.body(weight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                      Text(data.recent[i].hospitalName ?? '—', style: AppTextStyles.caption, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                  StatusBadge(status: data.recent[i].status, label: data.recent[i].statusLabel),
                  const SizedBox(width: 14),
                  if (!Responsive.isPhone(context))
                    SizedBox(
                      width: 92,
                      child: Text(Fmt.ago(data.recent[i].updatedAt), textAlign: TextAlign.right, style: AppTextStyles.caption),
                    ),
                ]),
              ),
            ).animate().fadeIn(duration: 250.ms, delay: (300 + 40 * i).ms),
      ]),
    );
  }
}
