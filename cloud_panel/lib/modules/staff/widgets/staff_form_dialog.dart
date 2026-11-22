import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/navigation.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/form_fields.dart';
import '../../../core/widgets/select_field.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/models/network_models.dart';
import '../../../data/models/paged.dart';
import '../../../data/repositories/network_repository.dart';

/// Add / edit a staff member (web "Add Staff" / "Edit Staff Detail").
///  - admin / OEM pass [clientId] (clients.id) of the client being managed
///  - a client user may also choose which of their cardiologists the
///    technician's ECGs go to ([withCardiologist])
class StaffFormDialog extends StatefulWidget {
  const StaffFormDialog({super.key, this.staff, this.clientId, this.clientName, this.withCardiologist = false});

  final StaffModel? staff;
  final int? clientId;
  final String? clientName;
  final bool withCardiologist;

  /// Returns true when saved.
  static Future<bool> open({StaffModel? staff, int? clientId, String? clientName, bool withCardiologist = false}) async {
    final r = await AppDialogs.showAnimated<bool>(
      StaffFormDialog(staff: staff, clientId: clientId, clientName: clientName, withCardiologist: withCardiologist),
      dismissible: false,
    );
    return r ?? false;
  }

  @override
  State<StaffFormDialog> createState() => _StaffFormDialogState();
}

class _StaffFormDialogState extends State<StaffFormDialog> {
  final _repo = StaffRepository();
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.staff?.name);
  late final _email = TextEditingController(text: widget.staff?.email);
  late final _phone = TextEditingController(text: widget.staff?.phoneNumber);
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  LookupItem? _cardiologist;
  Map<String, String> _errors = {};
  bool _saving = false;

  bool get _editing => widget.staff != null;

  @override
  void initState() {
    super.initState();
    final s = widget.staff;
    if (s?.cardiologistId != null) _cardiologist = LookupItem(s!.cardiologistId!, s.cardiologistName ?? 'Cardiologist');
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
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'email': _email.text.trim(),
      'phone_number': _phone.text.trim(),
      if (_password.text.isNotEmpty) 'password': _password.text,
      if (_password.text.isNotEmpty) 'password_confirmation': _confirm.text,
      if (widget.clientId != null) 'client_id': widget.clientId,
      if (widget.withCardiologist && _cardiologist != null) 'cardiologist_id': _cardiologist!.id,
    };
    try {
      final msg = _editing ? await _repo.update(widget.staff!.id, body) : await _repo.create(body);
      AppToast.success(msg);
      closeRoute(true);
    } on ApiException catch (e) {
      setState(() => _errors = e.fieldErrors);
      if (e.fieldErrors.isEmpty) AppToast.error(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 520, maxHeight: MediaQuery.sizeOf(context).height * .92),
      child: PanelScaffold(
        title: _editing ? 'Edit staff' : 'Add staff',
        subtitle: widget.clientName == null ? null : 'For ${widget.clientName}',
        body: Form(
          key: _key,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AppTextField(label: 'Name', controller: _name, required: true, serverError: _errors['name']),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Email',
              controller: _email,
              required: true,
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
              serverError: _errors['email'],
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Phone number',
              controller: _phone,
              required: true,
              keyboardType: TextInputType.phone,
              validator: Validators.phone,
              serverError: _errors['phone_number'],
            ),
            if (widget.withCardiologist) ...[
              const SizedBox(height: 14),
              LookupField(
                label: 'Cardiologist',
                value: _cardiologist,
                hint: 'Choose who reports this technician\'s ECGs',
                errorText: _errors['cardiologist_id'],
                onClear: () => setState(() => _cardiologist = null),
                onTap: () async {
                  final r = await SelectSheet.pick<LookupItem>(
                    title: 'Cardiologist',
                    load: LookupRepository().cardiologists,
                    labelOf: (i) => i.name,
                    selected: _cardiologist,
                  );
                  if (r?.value != null) setState(() => _cardiologist = r!.value);
                },
              ),
            ],
            const SizedBox(height: 18),
            Text(_editing ? 'Change password (leave blank to keep the current one)' : 'Sign-in password',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 10),
            AppTextField(
              label: 'Password',
              controller: _password,
              password: true,
              required: !_editing,
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
          Expanded(child: SecondaryButton(label: 'Cancel', onPressed: _saving ? null : () => closeRoute(false))),
          const SizedBox(width: 10),
          Expanded(child: PrimaryButton(label: _editing ? 'Save changes' : 'Add staff', loading: _saving, onPressed: _save)),
        ]),
      ),
    );
  }
}
