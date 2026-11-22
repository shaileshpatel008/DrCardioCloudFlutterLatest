import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/form_fields.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/models/network_models.dart';
import '../../../data/repositories/network_repository.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// Add / edit / view an OEM user in a side drawer. In view mode the summary
/// (clients and cardiologists they own) is shown with an Edit button.
class OemUserForm extends StatefulWidget {
  const OemUserForm({super.key, this.existing, this.viewOnly = false});
  final OemUserModel? existing;
  final bool viewOnly;

  static Future<bool> open({OemUserModel? existing, bool viewOnly = false}) async =>
      (await AppDialogs.showSidePanel<bool>(OemUserForm(existing: existing, viewOnly: viewOnly), width: 460)) ?? false;

  @override
  State<OemUserForm> createState() => _OemUserFormState();
}

class _OemUserFormState extends State<OemUserForm> {
  final _repo = OemUserRepository();
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _email = TextEditingController(text: widget.existing?.email);
  late final _phone = TextEditingController(text: widget.existing?.phoneNumber);
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  Map<String, String> _errors = {};
  bool _saving = false;
  late bool _viewing = widget.viewOnly;
  OemUserModel? _detail;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_editing) {
      _repo.detail(widget.existing!.id).then((d) {
        if (mounted) setState(() => _detail = d);
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _errors = {});
    if (!(_key.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final body = {
      'name': _name.text.trim(),
      'email': _email.text.trim(),
      'phone_number': _phone.text.trim(),
      if (_password.text.isNotEmpty) 'password': _password.text,
      if (_password.text.isNotEmpty) 'password_confirmation': _confirm.text,
    };
    try {
      final msg = _editing ? await _repo.update(widget.existing!.id, body) : await _repo.create(body);
      AppToast.success(msg);
      Get.back(result: true);
    } on ApiException catch (e) {
      setState(() => _errors = e.fieldErrors);
      if (e.fieldErrors.isEmpty) AppToast.error(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.existing;
    final summary = u == null
        ? null
        : Container(
            color: AppColors.surfaceAlt,
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
            child: Row(children: [
              InitialsAvatar(u.name, size: 52, radius: 14),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u.name, style: AppTextStyles.body(weight: FontWeight.w700)),
                  Text('Created ${Fmt.date(_detail?.createdAt ?? u.updatedAt)}', style: AppTextStyles.caption),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, children: [
                    _pill('${_detail?.clientsCount ?? u.clientsCount} clients'),
                    if (_detail?.cardiologistsCount != null) _pill('${_detail!.cardiologistsCount} cardiologists'),
                  ]),
                ]),
              ),
            ]),
          );

    if (_viewing && u != null) {
      return PanelScaffold(
        title: 'OEM user',
        header: summary,
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InfoTile(label: 'Name', value: u.name),
          const SizedBox(height: 16),
          InfoTile(label: 'Email', value: u.email),
          const SizedBox(height: 16),
          InfoTile(label: 'Phone number', value: u.phoneNumber),
          const SizedBox(height: 16),
          InfoTile(label: 'Last updated', value: Fmt.dateTime(u.updatedAt)),
        ]),
        footer: Row(children: [
          Expanded(child: SecondaryButton(label: 'Close', onPressed: () => Get.back(result: false))),
          const SizedBox(width: 10),
          Expanded(child: PrimaryButton(label: 'Edit', icon: Icons.edit_outlined, onPressed: () => setState(() => _viewing = false))),
        ]),
      );
    }

    return PanelScaffold(
      title: _editing ? 'Edit OEM user' : 'Add OEM user',
      subtitle: 'Partner / distributor account with its own clients, cardiologists and devices.',
      header: summary,
      body: Form(
        key: _key,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AppTextField(label: 'Name', controller: _name, required: true, serverError: _errors['name']),
          const SizedBox(height: 14),
          AppTextField(label: 'Email', controller: _email, required: true, keyboardType: TextInputType.emailAddress, validator: Validators.email, serverError: _errors['email']),
          const SizedBox(height: 14),
          AppTextField(label: 'Phone number', controller: _phone, required: true, keyboardType: TextInputType.phone, validator: Validators.phone, serverError: _errors['phone_number']),
          const Divider(height: 34),
          Text(_editing ? 'Change password (optional)' : 'Sign-in password', style: AppTextStyles.label),
          const SizedBox(height: 10),
          AppTextField(
            label: _editing ? 'New password' : 'Password',
            controller: _password,
            password: true,
            required: !_editing,
            hint: _editing ? 'Leave blank to keep current' : null,
            validator: (v) => Validators.password(v, optional: _editing),
            serverError: _errors['password'],
          ),
          PasswordStrength(controller: _password),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Confirm password',
            controller: _confirm,
            password: true,
            required: !_editing,
            validator: (v) => Validators.confirm(v, _password.text, optional: _editing),
          ),
        ]),
      ),
      footer: Row(children: [
        Expanded(child: SecondaryButton(label: 'Cancel', onPressed: _saving ? null : () => Get.back(result: false))),
        const SizedBox(width: 10),
        Expanded(child: PrimaryButton(label: _editing ? 'Update' : 'Save', loading: _saving, onPressed: _save)),
      ]),
    );
  }

  Widget _pill(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: AppColors.blueTint, borderRadius: BorderRadius.circular(999)),
        child: Text(t, style: AppTextStyles.body(size: 12, weight: FontWeight.w600, color: AppColors.blue)),
      );
}
