import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../data/models/ecg_record_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../utils/formatters.dart';

/// White rounded card with the panel's hairline border.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.radius = 18, this.color, this.clip = false});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.line),
        boxShadow: const [BoxShadow(color: Color(0x08101828), blurRadius: 2, offset: Offset(0, 1))],
      ),
      padding: padding,
      child: child,
    );
  }
}

/// Report status pill: dot + label, never colour alone.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.label, this.dense = false});

  final ReportStatus status;
  final String? label;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, dot) = switch (status) {
      ReportStatus.pending => (AppColors.pendingBg, AppColors.pendingText, AppColors.pending),
      ReportStatus.requested => (AppColors.requestedBg, AppColors.requestedText, AppColors.requested),
      ReportStatus.reported => (AppColors.reportedBg, AppColors.reportedText, AppColors.reported),
      ReportStatus.noCredit => (AppColors.noCreditBg, AppColors.noCreditText, AppColors.noCredit),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 2 : 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label ?? status.label, style: AppTextStyles.body(size: 12, weight: FontWeight.w600, color: fg)),
      ]),
    );
  }
}

/// "Normal" / "Abnormal" outline tag.
class EcgTag extends StatelessWidget {
  const EcgTag(this.value, {super.key});
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null) return const SizedBox.shrink();
    final abnormal = value == 'abnormal';
    final color = abnormal ? AppColors.dangerText : AppColors.reportedText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: abnormal ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0)),
      ),
      child: Text(
        value![0].toUpperCase() + value!.substring(1),
        style: AppTextStyles.body(size: 11, weight: FontWeight.w600, color: color),
      ),
    );
  }
}

class CountPill extends StatelessWidget {
  const CountPill(this.count, {super.key, this.active = true});
  final int count;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(color: active ? AppColors.brandTint : AppColors.lineSoft, borderRadius: BorderRadius.circular(999)),
      child: Text(Fmt.number(count),
          style: AppTextStyles.body(size: 12.5, weight: FontWeight.w700, color: active ? AppColors.brandDark : AppColors.muted)),
    );
  }
}

/// Rounded initials avatar with a stable tint per name.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.name, {super.key, this.size = 40, this.radius = 11, this.tintIndex});

  final String name;
  final double size;
  final double radius;
  final int? tintIndex;

  static const _tints = [
    (AppColors.blueTint, AppColors.blue),
    (AppColors.brandTint, AppColors.brandDark),
    (AppColors.greenTint, AppColors.green),
    (AppColors.violetTint, AppColors.violet),
    (AppColors.amberTint, AppColors.amber),
  ];

  @override
  Widget build(BuildContext context) {
    final i = (tintIndex ?? name.codeUnits.fold<int>(0, (a, b) => a + b)) % _tints.length;
    final (bg, fg) = _tints[i];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(radius)),
      child: Text(Fmt.initials(name), style: AppTextStyles.body(size: size * 0.34, weight: FontWeight.w700, color: fg)),
    );
  }
}

/// Square icon button with tooltip (table row actions).
class IconAction extends StatelessWidget {
  const IconAction({super.key, required this.icon, required this.tooltip, required this.onPressed, this.danger = false, this.color});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool danger;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = danger ? AppColors.dangerText : (color ?? AppColors.body);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: danger ? AppColors.dangerLine : AppColors.line),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            hoverColor: danger ? AppColors.dangerBg : AppColors.surfaceAlt,
            onTap: onPressed,
            child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 18, color: onPressed == null ? AppColors.faint : fg)),
          ),
        ),
      ),
    );
  }
}

/// Filled brand button that shows a spinner while [loading].
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onPressed, this.icon, this.loading = false, this.expand = false, this.danger = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final child = AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: loading
          ? const SizedBox(key: ValueKey('l'), width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
          : Row(key: const ValueKey('t'), mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ]),
    );
    final button = ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: danger
          ? ElevatedButton.styleFrom(backgroundColor: AppColors.danger, disabledBackgroundColor: AppColors.danger.withValues(alpha: .6))
          : ElevatedButton.styleFrom(disabledBackgroundColor: AppColors.brand.withValues(alpha: .6), disabledForegroundColor: Colors.white),
      child: child,
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, this.onPressed, this.icon, this.danger = false, this.expand = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool danger;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onPressed,
      style: danger
          ? OutlinedButton.styleFrom(foregroundColor: AppColors.dangerText, side: const BorderSide(color: AppColors.dangerLine))
          : null,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ]),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Small "NEW" tag for additions that the old panel did not have.
class NewTag extends StatelessWidget {
  const NewTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(color: AppColors.newTagBg, borderRadius: BorderRadius.circular(999)),
      child: Text('NEW', style: AppTextStyles.body(size: 10, weight: FontWeight.w700, color: AppColors.newTagText)),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.subtitle});
  final String text;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text, style: AppTextStyles.h3),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle!, style: AppTextStyles.body(size: 13, color: AppColors.muted)),
          ],
        ]),
      ),
      ?trailing,
    ]);
  }
}

/// Label above a value (detail screens).
class InfoTile extends StatelessWidget {
  const InfoTile({super.key, required this.label, this.value, this.child, this.mono = false});
  final String label;
  final String? value;
  final Widget? child;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: AppTextStyles.caption),
      const SizedBox(height: 4),
      child ??
          SelectableText(
            (value == null || value!.isEmpty) ? '—' : value!,
            style: mono ? AppTextStyles.mono.copyWith(fontWeight: FontWeight.w600) : AppTextStyles.body(weight: FontWeight.w600),
          ),
    ]);
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.message, this.icon = Icons.monitor_heart_outlined, this.action});
  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: AppColors.ground, borderRadius: BorderRadius.circular(18)),
          child: Icon(icon, size: 30, color: AppColors.faint),
        ),
        const SizedBox(height: 14),
        Text(title, style: AppTextStyles.body(size: 16, weight: FontWeight.w700), textAlign: TextAlign.center),
        if (message != null) ...[
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(message!, style: AppTextStyles.muted, textAlign: TextAlign.center),
          ),
        ],
        if (action != null) ...[const SizedBox(height: 16), action!],
      ]),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: .05, end: 0);
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Couldn\'t load this',
      message: message,
      action: onRetry == null ? null : SecondaryButton(label: 'Try again', icon: Icons.refresh_rounded, onPressed: onRetry),
    );
  }
}

/// Shimmering placeholder block for loading states.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 8});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: const Color(0xFFEEF0F3), borderRadius: BorderRadius.circular(radius)),
    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: const Color(0xFFF7F8FA));
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.rows = 6});
  final int rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        rows,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(children: [
            const SkeletonBox(width: 36, height: 36, radius: 9),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SkeletonBox(width: 220 - (i % 3) * 40.0, height: 12),
                const SizedBox(height: 7),
                SkeletonBox(width: 140 - (i % 2) * 30.0, height: 10),
              ]),
            ),
            const SkeletonBox(width: 80, height: 22, radius: 999),
          ]),
        ),
      ),
    );
  }
}

/// Animated count-up for KPI figures.
class CountUpText extends StatelessWidget {
  const CountUpText(this.value, {super.key, required this.style});
  final int value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text(Fmt.number(v.round()), style: style),
    );
  }
}
