import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/navigation.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/form_fields.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/models/network_models.dart';
import '../../../data/repositories/network_repository.dart';

/// Add / edit cardiologist: name, email, phone, address, password (+ confirm).
class CardiologistForm extends StatefulWidget {
  const CardiologistForm({super.key, this.existing});
  final CardiologistModel? existing;

  static Future<bool> open({CardiologistModel? existing}) async =>
      (await AppDialogs.showSidePanel<bool>(CardiologistForm(existing: existing))) ?? false;

  @override
  State<CardiologistForm> createState() => _CardiologistFormState();
}

class _CardiologistFormState extends State<CardiologistForm> {
  final _repo = CardiologistRepository();
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _email = TextEditingController(text: widget.existing?.email);
  late final _phone = TextEditingController(text: widget.existing?.phoneNumber);
  late final _address = TextEditingController(text: widget.existing?.address);
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  Map<String, String> _errors = {};
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _address, _password, _confirm]) {
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
      'address': _address.text.trim(),
      if (_password.text.isNotEmpty) 'password': _password.text,
      if (_password.text.isNotEmpty) 'password_confirmation': _confirm.text,
    };
    try {
      final msg = _editing ? await _repo.update(widget.existing!.id, body) : await _repo.create(body);
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
    return PanelScaffold(
      title: _editing ? 'Edit cardiologist' : 'Add cardiologist',
      subtitle: 'All fields are required${_editing ? ' (password only to change it)' : ''}.',
      body: Form(
        key: _key,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AppTextField(label: 'Name', controller: _name, hint: 'Dr. Full Name', required: true, serverError: _errors['name']),
          const SizedBox(height: 14),
          AppTextField(label: 'Email', controller: _email, required: true, keyboardType: TextInputType.emailAddress, validator: Validators.email, serverError: _errors['email']),
          const SizedBox(height: 14),
          AppTextField(label: 'Phone number', controller: _phone, required: true, keyboardType: TextInputType.phone, validator: Validators.phone, serverError: _errors['phone_number']),
          const SizedBox(height: 14),
          AppTextField(label: 'Address', controller: _address, required: true, hint: 'City, State', serverError: _errors['address']),
          const SizedBox(height: 14),
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
        Expanded(child: SecondaryButton(label: 'Cancel', onPressed: _saving ? null : () => closeRoute(false))),
        const SizedBox(width: 10),
        Expanded(child: PrimaryButton(label: _editing ? 'Save changes' : 'Save', loading: _saving, onPressed: _save)),
      ]),
    );
  }
}
