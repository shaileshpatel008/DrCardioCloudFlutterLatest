import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../utils/validators.dart';

/// Label-above text field with a required star, optional show/hide toggle
/// for passwords, and room for a server-side error under the field.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.required = false,
    this.password = false,
    this.validator,
    this.serverError,
    this.keyboardType,
    this.prefixIcon,
    this.prefixText,
    this.maxLines = 1,
    this.enabled = true,
    this.helper,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
    this.mono = false,
    this.readOnly = false,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final bool required;
  final bool password;
  final String? Function(String?)? validator;
  final String? serverError;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final String? prefixText;
  final int maxLines;
  final bool enabled;
  final String? helper;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final bool mono;
  final bool readOnly;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text.rich(TextSpan(children: [
        TextSpan(text: widget.label, style: AppTextStyles.label),
        if (widget.required) TextSpan(text: ' *', style: AppTextStyles.label.copyWith(color: AppColors.dangerText)),
      ])),
      const SizedBox(height: 7),
      TextFormField(
        controller: widget.controller,
        enabled: widget.enabled,
        readOnly: widget.readOnly,
        obscureText: widget.password && _obscure,
        keyboardType: widget.keyboardType,
        maxLines: widget.password ? 1 : widget.maxLines,
        minLines: widget.maxLines > 1 ? 2 : 1,
        validator: widget.validator ?? (widget.required ? (v) => Validators.required(v, widget.label) : null),
        onChanged: widget.onChanged,
        onFieldSubmitted: widget.onSubmitted,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints,
        inputFormatters: widget.inputFormatters,
        style: widget.mono ? AppTextStyles.mono.copyWith(fontSize: 14.5) : AppTextStyles.body(size: 15),
        decoration: InputDecoration(
          hintText: widget.hint,
          errorText: widget.serverError,
          errorMaxLines: 3,
          fillColor: widget.enabled && !widget.readOnly ? Colors.white : AppColors.surfaceAlt,
          prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon, size: 19, color: AppColors.subtle),
          prefixText: widget.prefixText,
          suffixIcon: widget.password
              ? IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 19, color: AppColors.subtle),
                  onPressed: () => setState(() => _obscure = !_obscure),
                )
              : null,
        ),
      ),
      if (widget.helper != null) ...[
        const SizedBox(height: 6),
        Text(widget.helper!, style: AppTextStyles.body(size: 12.5, color: AppColors.subtle, height: 1.4)),
      ],
    ]);
  }
}

/// 4-bar password strength meter shown under new-password fields.
class PasswordStrength extends StatelessWidget {
  const PasswordStrength({super.key, required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (_, v, _) {
        final score = Validators.strength(v.text);
        if (v.text.isEmpty) return const SizedBox.shrink();
        final color = switch (score) { <= 1 => AppColors.danger, 2 => AppColors.requested, _ => AppColors.success };
        final label = switch (score) { <= 1 => 'Weak password', 2 => 'Fair password', 3 => 'Good password', _ => 'Strong password' };
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              children: List.generate(
                4,
                (i) => Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 4,
                    margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                    decoration: BoxDecoration(color: i < score ? color : AppColors.line, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(label, style: AppTextStyles.body(size: 12, weight: FontWeight.w500, color: color)),
          ]),
        );
      },
    );
  }
}

/// Switch with a title and an explanation, used for client settings.
class SwitchTile extends StatelessWidget {
  const SwitchTile({super.key, required this.title, this.subtitle, required this.value, required this.onChanged, this.trailing});

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Switch(value: value, onChanged: onChanged),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AppTextStyles.body(weight: FontWeight.w600)),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: AppTextStyles.body(size: 13, color: AppColors.muted, height: 1.45)),
                ],
              ]),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ]),
      ),
    );
  }
}
