import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/paged.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'app_dialogs.dart';

/// Opens a searchable list (dialog on wide screens, sheet on phones) and
/// returns the chosen item. Passing [allowClear] adds an "All" row that
/// returns [SelectResult.cleared].
class SelectSheet {
  SelectSheet._();

  static Future<SelectResult<T>?> pick<T>({
    required String title,
    required Future<List<T>> Function() load,
    required String Function(T) labelOf,
    T? selected,
    bool allowClear = false,
    String clearLabel = 'All',
    String? subtitle,
  }) {
    return AppDialogs.showAnimated<SelectResult<T>>(
      _SelectBody<T>(
        title: title,
        subtitle: subtitle,
        load: load,
        labelOf: labelOf,
        selected: selected,
        allowClear: allowClear,
        clearLabel: clearLabel,
      ),
    );
  }
}

class SelectResult<T> {
  const SelectResult.value(this.value) : cleared = false;
  const SelectResult.cleared()
      : value = null,
        cleared = true;
  final T? value;
  final bool cleared;
}

class _SelectBody<T> extends StatefulWidget {
  const _SelectBody({
    required this.title,
    required this.load,
    required this.labelOf,
    this.selected,
    required this.allowClear,
    required this.clearLabel,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Future<List<T>> Function() load;
  final String Function(T) labelOf;
  final T? selected;
  final bool allowClear;
  final String clearLabel;

  @override
  State<_SelectBody<T>> createState() => _SelectBodyState<T>();
}

class _SelectBodyState<T> extends State<_SelectBody<T>> {
  List<T> _all = [];
  String _q = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _all = await widget.load();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final items = _q.isEmpty ? _all : _all.where((i) => widget.labelOf(i).toLowerCase().contains(_q.toLowerCase())).toList();
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 440, maxHeight: MediaQuery.sizeOf(context).height * .8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 6),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.title, style: AppTextStyles.h3),
                if (widget.subtitle != null) Text(widget.subtitle!, style: AppTextStyles.caption),
              ]),
            ),
            IconButton(tooltip: 'Close', onPressed: () => Get.back(), icon: const Icon(Icons.close_rounded)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(hintText: 'Search', prefixIcon: Icon(Icons.search_rounded, size: 20)),
          ),
        ),
        Flexible(
          child: _loading
              ? const Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())
              : _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_error!, style: AppTextStyles.muted, textAlign: TextAlign.center),
                        TextButton(onPressed: _fetch, child: const Text('Try again')),
                      ]),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
                      children: [
                        if (widget.allowClear && _q.isEmpty)
                          _row(widget.clearLabel, widget.selected == null, () => Get.back(result: SelectResult<T>.cleared())),
                        ...items.map((i) => _row(
                              widget.labelOf(i),
                              widget.selected != null && widget.selected == i,
                              () => Get.back(result: SelectResult<T>.value(i)),
                            )),
                        if (items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text('Nothing found', style: AppTextStyles.muted, textAlign: TextAlign.center),
                          ),
                      ],
                    ),
        ),
      ]),
    );
  }

  Widget _row(String label, bool selected, VoidCallback onTap) {
    return Material(
      color: selected ? AppColors.brandTint : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(children: [
            Expanded(
              child: Text(label,
                  style: AppTextStyles.body(
                      weight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? AppColors.brandDark : AppColors.ink)),
            ),
            if (selected) const Icon(Icons.check_rounded, size: 18, color: AppColors.brand),
          ]),
        ),
      ),
    );
  }
}

/// Form field that displays the chosen lookup and opens [SelectSheet].
class LookupField extends StatelessWidget {
  const LookupField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.hint = 'Select',
    this.required = false,
    this.errorText,
    this.enabled = true,
    this.onClear,
  });

  final String label;
  final LookupItem? value;
  final VoidCallback onTap;
  final String hint;
  final bool required;
  final String? errorText;
  final bool enabled;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text.rich(TextSpan(children: [
        TextSpan(text: label, style: AppTextStyles.label),
        if (required) TextSpan(text: ' *', style: AppTextStyles.label.copyWith(color: AppColors.dangerText)),
      ])),
      const SizedBox(height: 7),
      InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: InputDecorator(
          isEmpty: value == null,
          decoration: InputDecoration(
            errorText: errorText,
            fillColor: enabled ? Colors.white : AppColors.surfaceAlt,
            suffixIcon: value != null && onClear != null
                ? IconButton(tooltip: 'Clear', icon: const Icon(Icons.close_rounded, size: 18), onPressed: onClear)
                : const Icon(Icons.expand_more_rounded, color: AppColors.subtle),
          ),
          child: Text(
            value?.name ?? hint,
            style: AppTextStyles.body(size: 15, color: value == null ? AppColors.faint : AppColors.ink),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ]);
  }
}

/// Compact "Label: Value ▾" filter trigger used in filter bars.
class FilterButton extends StatelessWidget {
  const FilterButton({super.key, required this.label, required this.value, required this.onTap, this.active = false});
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.brandTint : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: active ? AppColors.brandSoft : AppColors.field),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 42, maxWidth: 280),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('$label ', style: AppTextStyles.body(size: 13.5, color: active ? AppColors.brandDark : AppColors.subtle)),
              Flexible(
                child: Text(value,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(size: 13.5, weight: FontWeight.w600, color: active ? AppColors.brandDark : AppColors.ink)),
              ),
              const SizedBox(width: 4),
              Icon(Icons.expand_more_rounded, size: 18, color: active ? AppColors.brandDark : AppColors.subtle),
            ]),
          ),
        ),
      ),
    );
  }
}
