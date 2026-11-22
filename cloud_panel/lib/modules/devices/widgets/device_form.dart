import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/navigation.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/form_fields.dart';
import '../../../core/widgets/select_field.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/models/network_models.dart';
import '../../../data/models/paged.dart';
import '../../../data/repositories/network_repository.dart';

/// Add / edit device: hospital (searchable) + instrument ID.
class DeviceForm extends StatefulWidget {
  const DeviceForm({super.key, this.existing, this.presetHospital});
  final DeviceModel? existing;
  final LookupItem? presetHospital;

  static Future<bool> open({DeviceModel? existing, LookupItem? presetHospital}) async =>
      (await AppDialogs.showSidePanel<bool>(DeviceForm(existing: existing, presetHospital: presetHospital), width: 440)) ?? false;

  @override
  State<DeviceForm> createState() => _DeviceFormState();
}

class _DeviceFormState extends State<DeviceForm> {
  final _repo = DeviceRepository();
  final _key = GlobalKey<FormState>();
  late final _instrument = TextEditingController(text: widget.existing?.instrumentId);
  LookupItem? _hospital;
  Map<String, String> _errors = {};
  String? _hospitalError;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _hospital = e?.hospitalId != null ? LookupItem(e!.hospitalId!, e.hospitalName ?? 'Hospital') : widget.presetHospital;
  }

  @override
  void dispose() {
    _instrument.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _errors = {};
      _hospitalError = _hospital == null ? 'Please choose a hospital.' : null;
    });
    final valid = _key.currentState?.validate() ?? false;
    if (!valid || _hospital == null) return;
    setState(() => _saving = true);
    try {
      final msg = _editing
          ? await _repo.update(widget.existing!.id, _hospital!.id, _instrument.text)
          : await _repo.create(_hospital!.id, _instrument.text);
      AppToast.success(msg);
      closeRoute(true);
    } on ApiException catch (e) {
      setState(() {
        _errors = e.fieldErrors;
        _hospitalError = e.errorFor('hospital_id') ?? e.errorFor('hospital_name');
      });
      if (e.fieldErrors.isEmpty) AppToast.error(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PanelScaffold(
      title: _editing ? 'Edit device' : 'Add device',
      subtitle: 'Link a Dr. Cardio device to a hospital.',
      body: Form(
        key: _key,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          LookupField(
            label: 'Hospital',
            required: true,
            value: _hospital,
            hint: 'Search hospitals',
            errorText: _hospitalError,
            onTap: () async {
              final r = await SelectSheet.pick<LookupItem>(
                title: 'Hospital',
                load: LookupRepository().hospitals,
                labelOf: (i) => i.name,
                selected: _hospital,
              );
              if (r?.value != null) setState(() => _hospital = r!.value);
            },
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Instrument ID',
            controller: _instrument,
            required: true,
            mono: true,
            hint: 'Dr.Cardio/261-A1F3',
            helper: 'Printed on the device label.',
            serverError: _errors['intrument_id'],
          ),
        ]),
      ),
      footer: Row(children: [
        Expanded(child: SecondaryButton(label: 'Cancel', onPressed: _saving ? null : () => closeRoute(false))),
        const SizedBox(width: 10),
        Expanded(child: PrimaryButton(label: _editing ? 'Save changes' : 'Save device', loading: _saving, onPressed: _save)),
      ]),
    );
  }
}
