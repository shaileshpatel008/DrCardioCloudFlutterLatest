import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/data_table.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/models/network_models.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../shell/app_shell.dart';
import '../controllers/cardiologists_controller.dart';

class CardiologistsView extends GetView<CardiologistsController> {
  const CardiologistsView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return AppShell(
      active: 'cardiologists',
      title: 'Cardiologists',
      floatingActionButton: Responsive.isPhone(context)
          ? FloatingActionButton.extended(
              onPressed: c.add,
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add cardiologist'),
            )
          : null,
      child: PageBody(onRefresh: c.refreshList, children: [
        Obx(() => PageHeader(
              breadcrumb: 'Network / Cardiologists',
              title: 'Cardiologists',
              count: c.total.value,
              subtitle: 'The reporting panel that reviews ECGs sent by clients.',
              actions: [if (!Responsive.isPhone(context)) PrimaryButton(label: 'Add cardiologist', icon: Icons.add_rounded, onPressed: c.add)],
            )),
        SizedBox(
          width: Responsive.isPhone(context) ? double.infinity : 420,
          child: SearchBox(hint: 'Search name, email, phone…', onChanged: c.setSearch),
        ),
        Obx(() {
          final items = c.items.toList();
          if (c.isLoading.value && items.isEmpty) return const AppCard(padding: EdgeInsets.zero, child: SkeletonList(rows: 4));
          if (c.error.value != null && items.isEmpty) return AppCard(child: ErrorState(message: c.error.value!, onRetry: c.load));
          if (items.isEmpty) {
            return const AppCard(
              child: EmptyState(icon: Icons.favorite_border_rounded, title: 'No cardiologists found', message: 'Try another search, or add a cardiologist.'),
            );
          }
          return LayoutBuilder(builder: (context, box) {
            final cols = box.maxWidth >= 1100 ? 4 : box.maxWidth >= 760 ? 3 : box.maxWidth >= 520 ? 2 : 1;
            final w = (box.maxWidth - (cols - 1) * 14) / cols;
            return Wrap(spacing: 14, runSpacing: 14, children: [
              for (var i = 0; i < items.length; i++)
                SizedBox(
                  width: w,
                  child: _CardiologistCard(item: items[i], controller: c),
                ).animate().fadeIn(duration: 260.ms, delay: (40 * i).ms).slideY(begin: .08, end: 0),
            ]);
          });
        }),
        Obx(() => c.total.value == 0
            ? const SizedBox.shrink()
            : AppCard(
                padding: EdgeInsets.zero,
                child: PaginationBar(
                  page: c.page.value,
                  lastPage: c.lastPage.value,
                  total: c.total.value,
                  perPage: c.perPage.value,
                  from: c.from.value,
                  to: c.to.value,
                  onPage: c.setPage,
                  onPerPage: c.setPerPage,
                ),
              )),
      ]),
    );
  }
}

class _CardiologistCard extends StatefulWidget {
  const _CardiologistCard({required this.item, required this.controller});
  final CardiologistModel item;
  final CardiologistsController controller;

  @override
  State<_CardiologistCard> createState() => _CardiologistCardState();
}

class _CardiologistCardState extends State<_CardiologistCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.item;
    final c = widget.controller;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _hover ? AppColors.brandSoft : AppColors.line),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _hover ? .06 : .02), blurRadius: _hover ? 22 : 6, offset: const Offset(0, 8))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            InitialsAvatar(d.name, size: 48, radius: 14, tintIndex: 1),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.name, style: AppTextStyles.body(size: 15.5, weight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                Text('Updated ${Fmt.date(d.updatedAt)}', style: AppTextStyles.caption),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          _line(Icons.mail_outline_rounded, d.email),
          _line(Icons.call_outlined, d.phoneNumber ?? '—'),
          _line(Icons.place_outlined, d.address ?? '—'),
          _line(Icons.apartment_rounded, d.clientsCount == 1 ? '1 linked hospital' : '${d.clientsCount} linked hospitals'),
          const Divider(height: 22),
          Row(children: [
            Expanded(child: SecondaryButton(label: 'View', onPressed: () => c.view(d))),
            const SizedBox(width: 6),
            Expanded(child: SecondaryButton(label: 'Edit', onPressed: () => c.edit(d))),
            const SizedBox(width: 6),
            IconAction(icon: Icons.delete_outline_rounded, tooltip: 'Delete', danger: true, onPressed: () => c.delete(d)),
          ]),
        ]),
      ),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(children: [
          Icon(icon, size: 15, color: AppColors.subtle),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.body(size: 13, color: AppColors.body), overflow: TextOverflow.ellipsis)),
        ]),
      );
}
