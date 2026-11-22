import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../constants/app_constants.dart';
import '../utils/formatters.dart';
import '../utils/responsive.dart';

/// Column definition for [ResponsiveTable].
class TableCol<T> {
  const TableCol({required this.title, required this.cell, this.flex = 1, this.sortKey, this.alignEnd = false, this.minWidth});

  final String title;
  final Widget Function(T row) cell;
  final int flex;
  final String? sortKey;
  final bool alignEnd;
  final double? minWidth;
}

/// Wide screens: a real table (sortable headers, hover rows, horizontal
/// scroll if needed). Phones: one card per row via [mobileCard].
class ResponsiveTable<T> extends StatelessWidget {
  const ResponsiveTable({
    super.key,
    required this.rows,
    required this.columns,
    required this.mobileCard,
    this.onRowTap,
    this.sortKey,
    this.sortAsc = false,
    this.onSort,
    this.minTableWidth = 900,
  });

  final List<T> rows;
  final List<TableCol<T>> columns;
  final Widget Function(T row) mobileCard;
  final void Function(T row)? onRowTap;
  final String? sortKey;
  final bool sortAsc;
  final void Function(String key)? onSort;
  final double minTableWidth;

  @override
  Widget build(BuildContext context) {
    if (Responsive.isPhone(context)) {
      return Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.line)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onRowTap == null ? null : () => onRowTap!(rows[i]),
                  child: Padding(padding: const EdgeInsets.all(14), child: mobileCard(rows[i])),
                ),
              ),
            ).animate().fadeIn(duration: 250.ms, delay: (30 * i).ms).slideY(begin: .08, end: 0),
        ],
      );
    }

    return LayoutBuilder(builder: (context, c) {
      final width = c.maxWidth < minTableWidth ? minTableWidth : c.maxWidth;
      final table = SizedBox(
        width: width,
        child: Column(children: [
          Container(
            color: AppColors.surfaceAlt,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(children: [
              for (final col in columns)
                Expanded(
                  flex: col.flex,
                  child: Align(
                    alignment: col.alignEnd ? Alignment.centerRight : Alignment.centerLeft,
                    child: _HeaderCell(
                      title: col.title,
                      sortable: col.sortKey != null && onSort != null,
                      active: col.sortKey != null && col.sortKey == sortKey,
                      asc: sortAsc,
                      onTap: col.sortKey == null || onSort == null ? null : () => onSort!(col.sortKey!),
                    ),
                  ),
                ),
            ]),
          ),
          for (var i = 0; i < rows.length; i++)
            _HoverRow(
              onTap: onRowTap == null ? null : () => onRowTap!(rows[i]),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                for (final col in columns)
                  Expanded(
                    flex: col.flex,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Align(
                        alignment: col.alignEnd ? Alignment.centerRight : Alignment.centerLeft,
                        child: col.cell(rows[i]),
                      ),
                    ),
                  ),
              ]),
            ).animate().fadeIn(duration: 220.ms, delay: (18 * i).ms),
        ]),
      );
      if (c.maxWidth >= minTableWidth) return table;
      return Scrollbar(
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: table),
      );
    });
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.title, required this.sortable, required this.active, required this.asc, this.onTap});
  final String title;
  final bool sortable;
  final bool active;
  final bool asc;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(title.toUpperCase(), style: AppTextStyles.tableHeader.copyWith(color: active ? AppColors.ink : null));
    if (!sortable) return text;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          text,
          const SizedBox(width: 4),
          Icon(
            active ? (asc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded) : Icons.unfold_more_rounded,
            size: 14,
            color: active ? AppColors.ink : AppColors.faint,
          ),
        ]),
      ),
    );
  }
}

class _HoverRow extends StatefulWidget {
  const _HoverRow({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: _hover ? const Color(0xFFFCFCFD) : Colors.white,
            border: const Border(top: BorderSide(color: AppColors.lineSoft)),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// "Rows per page · Showing 1–10 of N · ‹ 1 2 3 … N ›"
class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.page,
    required this.lastPage,
    required this.total,
    required this.perPage,
    required this.from,
    required this.to,
    required this.onPage,
    required this.onPerPage,
  });

  final int page, lastPage, total, perPage, from, to;
  final ValueChanged<int> onPage;
  final ValueChanged<int> onPerPage;

  @override
  Widget build(BuildContext context) {
    final phone = Responsive.isPhone(context);
    final info = Text(
      total == 0 ? 'No results' : 'Showing ${Fmt.number(from)}–${Fmt.number(to)} of ${Fmt.number(total)}',
      style: AppTextStyles.body(size: 13.5, color: AppColors.muted),
    );
    final perPageSelect = Row(mainAxisSize: MainAxisSize.min, children: [
      Text('Rows', style: AppTextStyles.body(size: 13.5, color: AppColors.muted)),
      const SizedBox(width: 8),
      PopupMenuButton<int>(
        tooltip: 'Rows per page',
        initialValue: perPage,
        onSelected: onPerPage,
        itemBuilder: (_) => [for (final s in AppConstants.pageSizes) PopupMenuItem(value: s, child: Text('$s'))],
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(border: Border.all(color: AppColors.field), borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('$perPage', style: AppTextStyles.body(weight: FontWeight.w600)),
            const Icon(Icons.expand_more_rounded, size: 16),
          ]),
        ),
      ),
    ]);

    final pages = _pageNumbers();
    final nav = Row(mainAxisSize: MainAxisSize.min, children: [
      _NavBtn(icon: Icons.chevron_left_rounded, tooltip: 'Previous page', onTap: page > 1 ? () => onPage(page - 1) : null),
      if (!phone)
        for (final p in pages)
          p == null
              ? const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('…'))
              : _PageBtn(number: p, active: p == page, onTap: () => onPage(p))
      else
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('$page / $lastPage', style: AppTextStyles.body(weight: FontWeight.w600)),
        ),
      _NavBtn(icon: Icons.chevron_right_rounded, tooltip: 'Next page', onTap: page < lastPage ? () => onPage(page + 1) : null),
    ]);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 10,
        spacing: 16,
        children: [
          Wrap(spacing: 16, crossAxisAlignment: WrapCrossAlignment.center, children: [perPageSelect, info]),
          nav,
        ],
      ),
    );
  }

  List<int?> _pageNumbers() {
    if (lastPage <= 7) return [for (var i = 1; i <= lastPage; i++) i];
    final set = <int>{1, 2, page - 1, page, page + 1, lastPage - 1, lastPage}..removeWhere((p) => p < 1 || p > lastPage);
    final sorted = set.toList()..sort();
    final out = <int?>[];
    for (var i = 0; i < sorted.length; i++) {
      if (i > 0 && sorted[i] - sorted[i - 1] > 1) out.add(null);
      out.add(sorted[i]);
    }
    return out;
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.icon, required this.tooltip, this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(border: Border.all(color: AppColors.field), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 20, color: onTap == null ? AppColors.faint : AppColors.body),
        ),
      ),
    );
  }
}

class _PageBtn extends StatelessWidget {
  const _PageBtn({required this.number, required this.active, required this.onTap});
  final int number;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minWidth: 36),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: active ? AppColors.brand : Colors.transparent, borderRadius: BorderRadius.circular(8)),
          child: Text(Fmt.number(number),
              style: AppTextStyles.body(weight: FontWeight.w600, color: active ? Colors.white : AppColors.body)),
        ),
      ),
    );
  }
}

/// Search box that waits for the user to stop typing before searching.
class SearchBox extends StatefulWidget {
  const SearchBox({super.key, required this.onChanged, this.hint = 'Search', this.initial = ''});
  final ValueChanged<String> onChanged;
  final String hint;
  final String initial;

  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _changed(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => widget.onChanged(v));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      onChanged: _changed,
      onSubmitted: widget.onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.subtle),
        suffixIcon: _c.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _c.clear();
                  _changed('');
                },
              ),
      ),
    );
  }
}
