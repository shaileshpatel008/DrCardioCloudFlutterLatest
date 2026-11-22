import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/navigation.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/data_table.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/models/network_models.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../shell/app_shell.dart';
import '../controllers/client_detail_controller.dart';

class ClientDetailView extends GetView<ClientDetailController> {
  const ClientDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      active: 'clients',
      title: 'Client',
      child: Obx(() {
        final c = controller.client.value;
        if (controller.loading.value && c == null) return const Center(child: CircularProgressIndicator());
        if (c == null) return ErrorState(message: controller.error.value ?? 'Client not found.', onRetry: controller.load);
        return PageBody(onRefresh: controller.load, children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(onPressed: () => closeRoute(null, AppRoutes.clients), icon: const Icon(Icons.arrow_back_rounded, size: 18), label: const Text('Clients')),
          ),
          _Profile(controller: controller, client: c),
          _Tabs(controller: controller, client: c),
        ]);
      }),
    );
  }
}

class _Profile extends StatelessWidget {
  const _Profile({required this.controller, required this.client});
  final ClientDetailController controller;
  final ClientModel client;

  @override
  Widget build(BuildContext context) {
    final c = client;
    final phone = Responsive.isPhone(context);
    return AppCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 92,
          color: AppColors.sidebar,
          child: CustomPaint(painter: _HeaderTrace()),
        ),
        Transform.translate(
          offset: const Offset(0, -36),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.end, runSpacing: 14, spacing: 16, children: [
              Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 4), borderRadius: BorderRadius.circular(22)),
                  child: InitialsAvatar(c.hospitalName, size: 80, radius: 18),
                ).animate().scale(begin: const Offset(.8, .8), duration: 400.ms, curve: Curves.easeOutBack),
                const SizedBox(width: 16),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(c.hospitalName, style: AppTextStyles.display(phone ? 22 : 26)),
                      const SizedBox(height: 4),
                      Text('${c.doctorName ?? ''} · Client since ${Fmt.date(c.createdAt)}', style: AppTextStyles.muted),
                    ]),
                  ),
                ),
              ]),
              Wrap(spacing: 8, runSpacing: 8, children: [
                SecondaryButton(label: 'ECG records', icon: Icons.monitor_heart_outlined, onPressed: controller.openEcgRecords),
                SecondaryButton(label: 'Edit', icon: Icons.edit_outlined, onPressed: controller.edit),
                SecondaryButton(label: 'Delete', icon: Icons.delete_outline_rounded, danger: true, onPressed: controller.delete),
              ]),
            ]),
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(builder: (context, box) {
            final cols = box.maxWidth > 900 ? 4 : (box.maxWidth > 520 ? 2 : 1);
            final w = (box.maxWidth - (cols - 1) * 24) / cols;
            final balance = c.reportLimitEnabled ? '${Fmt.number(c.reportLimit)} reports left' : 'Unlimited';
            final tiles = <Widget>[
              InfoTile(label: 'Login name', value: c.name),
              InfoTile(label: 'Email', value: c.email),
              InfoTile(label: 'Phone', value: c.phoneNumber),
              InfoTile(label: 'Address', value: c.address),
              InfoTile(label: 'Cardiologist', value: c.multiHospitalAccess ? 'Chosen per staff (multi-hospital)' : (c.cardiologistName ?? 'Not assigned')),
              InfoTile(label: 'ECG balance', value: balance),
              InfoTile(
                label: 'Access',
                child: _pill(c.multiHospitalAccess ? 'Multi-hospital access' : 'Single hospital', c.multiHospitalAccess),
              ),
              InfoTile(
                label: 'Integrations',
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  _pill(c.webhookUrl == null ? 'Webhook off' : 'Webhook on', c.webhookUrl != null),
                  _pill(c.getPatientApiEnabled ? 'Get Patient API on' : 'Get Patient API off', c.getPatientApiEnabled),
                ]),
              ),
            ];
            return Wrap(spacing: 24, runSpacing: 20, children: [for (final t in tiles) SizedBox(width: w, child: t)]);
          }),
        ),
      ]),
    );
  }

  Widget _pill(String t, bool on) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: on ? AppColors.successBg : AppColors.lineSoft, borderRadius: BorderRadius.circular(6)),
        child: Text(t, style: AppTextStyles.body(size: 12, weight: FontWeight.w600, color: on ? AppColors.reportedText : AppColors.body)),
      );
}

class _HeaderTrace extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.brand
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    final y = size.height * .58;
    final x0 = size.width * .32;
    final path = Path()
      ..moveTo(0, y)
      ..lineTo(x0, y)
      ..lineTo(x0 + 12, y)
      ..lineTo(x0 + 18, y + 8)
      ..lineTo(x0 + 26, y - 38)
      ..lineTo(x0 + 34, y + 22)
      ..lineTo(x0 + 40, y)
      ..lineTo(x0 + 140, y)
      ..quadraticBezierTo(x0 + 152, y - 14, x0 + 164, y)
      ..lineTo(size.width, y);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.controller, required this.client});
  final ClientDetailController controller;
  final ClientModel client;

  @override
  Widget build(BuildContext context) {
    final staff = controller.staff;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Obx(() => Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 10, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              _tab('Staff', client.staffCount ?? staff.total.value, controller.tab.value == 0, () => controller.tab.value = 0),
              _tab('Devices', client.devices.length, controller.tab.value == 1, () => controller.tab.value = 1),
            ]),
            if (controller.tab.value == 0) PrimaryButton(label: 'Add staff', icon: Icons.person_add_alt_rounded, onPressed: staff.add),
          ])),
      const SizedBox(height: 12),
      Obx(() => controller.tab.value == 0
          ? PagedListCard<StaffModel>(
              controller: staff,
              minTableWidth: 760,
              emptyTitle: 'No staff yet',
              emptyMessage: 'Add the technicians who record ECGs for this client.',
              emptyIcon: Icons.groups_2_outlined,
              toolbar: SizedBox(
                width: Responsive.isPhone(context) ? double.infinity : 340,
                child: SearchBox(hint: 'Search staff', onChanged: staff.setSearch),
              ),
              columns: [
                TableCol(
                  title: 'Name',
                  flex: 4,
                  sortKey: 'name',
                  cell: (s) => Row(children: [
                    InitialsAvatar(s.name, size: 34, radius: 17, tintIndex: 3),
                    const SizedBox(width: 10),
                    Flexible(child: Text(s.name, style: AppTextStyles.body(weight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                  ]),
                ),
                TableCol(title: 'Email', flex: 4, sortKey: 'email', cell: (s) => Text(s.email, style: AppTextStyles.muted, overflow: TextOverflow.ellipsis)),
                TableCol(title: 'Phone', flex: 3, cell: (s) => Text(s.phoneNumber ?? '—', style: AppTextStyles.muted)),
                TableCol(title: 'Updated', flex: 2, sortKey: 'date', cell: (s) => Text(Fmt.date(s.updatedAt), style: AppTextStyles.muted)),
                TableCol(
                  title: 'Actions',
                  flex: 2,
                  alignEnd: true,
                  cell: (s) => Wrap(spacing: 6, children: [
                    IconAction(icon: Icons.edit_outlined, tooltip: 'Edit staff', onPressed: () => staff.edit(s)),
                    IconAction(icon: Icons.delete_outline_rounded, tooltip: 'Delete staff', danger: true, onPressed: () => staff.delete(s)),
                  ]),
                ),
              ],
              mobileCard: (s) => Row(children: [
                InitialsAvatar(s.name, size: 40, radius: 20, tintIndex: 3),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.name, style: AppTextStyles.body(weight: FontWeight.w700)),
                    Text(s.email, style: AppTextStyles.caption),
                    if (s.phoneNumber != null) Text(s.phoneNumber!, style: AppTextStyles.caption),
                  ]),
                ),
                IconAction(icon: Icons.edit_outlined, tooltip: 'Edit staff', onPressed: () => staff.edit(s)),
                const SizedBox(width: 6),
                IconAction(icon: Icons.delete_outline_rounded, tooltip: 'Delete staff', danger: true, onPressed: () => staff.delete(s)),
              ]),
            )
          : AppCard(
              child: client.devices.isEmpty
                  ? const EmptyState(icon: Icons.developer_board_rounded, title: 'No devices', message: 'Add devices for this client from the Devices page.')
                  : Wrap(spacing: 12, runSpacing: 12, children: [
                      for (final d in client.devices)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.developer_board_rounded, color: AppColors.green, size: 20),
                            const SizedBox(width: 10),
                            Text(d.instrumentId, style: AppTextStyles.mono.copyWith(fontWeight: FontWeight.w600)),
                          ]),
                        ),
                    ]),
            )),
    ]);
  }

  Widget _tab(String label, int count, bool active, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            border: Border.all(color: active ? AppColors.line : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Text(label, style: AppTextStyles.body(weight: FontWeight.w600, color: active ? AppColors.brand : AppColors.muted)),
            const SizedBox(width: 8),
            CountPill(count, active: active),
          ]),
        ),
      );
}
