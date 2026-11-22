import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../base/paged_list_controller.dart';
import '../utils/responsive.dart';
import 'data_table.dart';
import 'ui_kit.dart';

/// Breadcrumb + title (+ count) + subtitle on the left, actions on the right.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.breadcrumb, this.subtitle, this.count, this.actions = const []});

  final String title;
  final String? breadcrumb;
  final String? subtitle;
  final int? count;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final phone = Responsive.isPhone(context);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      runSpacing: 14,
      spacing: 16,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (breadcrumb != null && !phone) Text(breadcrumb!, style: AppTextStyles.body(size: 13, color: AppColors.subtle)),
          if (breadcrumb != null && !phone) const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: Text(title, style: AppTextStyles.display(phone ? 24 : 30))),
            if (count != null) ...[const SizedBox(width: 12), CountPill(count!)],
          ]),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Text(subtitle!, style: AppTextStyles.muted),
            ),
          ],
        ]),
        if (actions.isNotEmpty) Wrap(spacing: 10, runSpacing: 10, children: actions),
      ],
    ).animate().fadeIn(duration: 280.ms).slideY(begin: -.06, end: 0, curve: Curves.easeOutCubic);
  }
}

/// Scrollable page body with consistent padding and max width.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.maxWidth = 1400, this.onRefresh, this.gap = 20});

  final List<Widget> children;
  final double maxWidth;
  final Future<void> Function()? onRefresh;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      padding: Responsive.pagePadding(context),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) SizedBox(height: gap),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, color: AppColors.brand, child: list);
  }
}

/// The standard "toolbar + table + pagination" card for paginated lists.
class PagedListCard<T> extends StatelessWidget {
  const PagedListCard({
    super.key,
    required this.controller,
    required this.columns,
    required this.mobileCard,
    this.toolbar,
    this.onRowTap,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
    this.emptyIcon = Icons.inbox_outlined,
    this.minTableWidth = 900,
    this.below,
  });

  final PagedListController<T> controller;
  final List<TableCol<T>> columns;
  final Widget Function(T) mobileCard;
  final Widget? toolbar;
  final void Function(T)? onRowTap;
  final String emptyTitle;
  final String? emptyMessage;
  final IconData emptyIcon;
  final double minTableWidth;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final phone = Responsive.isPhone(context);
    return AppCard(
      padding: EdgeInsets.zero,
      clip: true,
      color: phone ? Colors.transparent : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (toolbar != null)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(bottom: BorderSide(color: AppColors.line)),
              borderRadius: phone ? BorderRadius.circular(16) : null,
            ),
            margin: phone ? const EdgeInsets.only(bottom: 12) : EdgeInsets.zero,
            padding: const EdgeInsets.all(14),
            child: toolbar,
          ),
        ?below,
        Obx(() {
          final loading = controller.isLoading.value;
          final err = controller.error.value;
          final rows = controller.items.toList();
          Widget body;
          if (loading && rows.isEmpty) {
            body = const SkeletonList();
          } else if (err != null && rows.isEmpty) {
            body = ErrorState(message: err, onRetry: controller.load);
          } else if (rows.isEmpty) {
            body = EmptyState(title: emptyTitle, message: emptyMessage, icon: emptyIcon);
          } else {
            body = Stack(children: [
              ResponsiveTable<T>(
                rows: rows,
                columns: columns,
                mobileCard: mobileCard,
                onRowTap: onRowTap,
                sortKey: controller.sortKey.value,
                sortAsc: controller.sortAsc.value,
                onSort: controller.toggleSort,
                minTableWidth: minTableWidth,
              ),
              if (loading)
                const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 2)),
            ]);
          }
          return AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: KeyedSubtree(key: ValueKey('$loading$err${rows.length}'), child: body));
        }),
        Obx(() => controller.total.value == 0
            ? const SizedBox.shrink()
            : Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: phone ? null : const Border(top: BorderSide(color: AppColors.line)),
                  borderRadius: phone ? BorderRadius.circular(16) : null,
                ),
                child: PaginationBar(
                  page: controller.page.value,
                  lastPage: controller.lastPage.value,
                  total: controller.total.value,
                  perPage: controller.perPage.value,
                  from: controller.from.value,
                  to: controller.to.value,
                  onPage: controller.setPage,
                  onPerPage: controller.setPerPage,
                ),
              )),
      ]),
    ).animate().fadeIn(duration: 320.ms, delay: 60.ms).slideY(begin: .03, end: 0);
  }
}

/// Helper to open a route by name and refresh a list when it returns true.
Future<void> openAndRefresh(String route, PagedListController controller, {dynamic arguments, Map<String, String>? parameters}) async {
  final changed = await Get.toNamed(route, arguments: arguments, parameters: parameters);
  if (changed == true) controller.refreshList();
}
