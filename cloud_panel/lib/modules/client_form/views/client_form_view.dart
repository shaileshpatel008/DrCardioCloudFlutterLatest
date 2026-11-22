import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../../core/utils/navigation.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/form_fields.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/select_field.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../shell/app_shell.dart';
import '../controllers/client_form_controller.dart';

class ClientFormView extends GetView<ClientFormController> {
  const ClientFormView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return AppShell(
      active: 'clients',
      title: c.editing ? 'Edit client' : 'Add client',
      child: Obx(() {
        if (c.loading.value) return const Center(child: CircularProgressIndicator());
        if (c.loadError.value != null) return ErrorState(message: c.loadError.value!);
        return Form(
          key: c.formKey,
          child: PageBody(
            maxWidth: 1000,
            gap: 16,
            children: [
              PageHeader(
                breadcrumb: 'Clients / ${c.editing ? 'Edit client' : 'Add client'}',
                title: c.editing ? 'Edit client' : 'Add client',
                subtitle: 'Fields marked * are required.',
              ),
              _Section(
                index: 0,
                title: 'Account login',
                subtitle: 'The client signs in to ECG Cloud and the mobile app with these details.',
                children: [
                  _row(context, [
                    Obx(() => AppTextField(label: 'Name', controller: c.name, required: true, serverError: c.error('name'))),
                    Obx(
                      () => AppTextField(
                        label: 'Email',
                        controller: c.email,
                        required: true,
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.email,
                        serverError: c.error('email'),
                        onChanged: (_) => c.defaultStaff.refresh(),
                      ),
                    ),
                  ]),
                  _row(context, [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Obx(
                          () => AppTextField(
                            label: c.editing ? 'New password' : 'Password',
                            controller: c.password,
                            password: true,
                            required: !c.editing,
                            hint: c.editing ? 'Leave blank to keep current' : null,
                            validator: (v) => Validators.password(v, optional: c.editing),
                            serverError: c.error('password'),
                          ),
                        ),
                        PasswordStrength(controller: c.password),
                      ],
                    ),
                    AppTextField(
                      label: 'Confirm password',
                      controller: c.confirm,
                      password: true,
                      required: !c.editing,
                      validator: (v) => Validators.confirm(v, c.password.text, optional: c.editing),
                    ),
                  ]),
                ],
              ),
              _Section(
                index: 1,
                title: 'Hospital details',
                children: [
                  _row(context, [
                    Obx(() => AppTextField(label: 'Hospital name', controller: c.hospital, required: true, serverError: c.error('hospital_name'))),
                    Obx(() => AppTextField(label: 'Doctor name', controller: c.doctor, required: true, serverError: c.error('doctor_name'))),
                  ]),
                  _row(context, [
                    Obx(
                      () => AppTextField(
                        label: 'Phone number',
                        controller: c.phone,
                        required: true,
                        keyboardType: TextInputType.phone,
                        validator: Validators.phone,
                        serverError: c.error('phone_number'),
                      ),
                    ),
                    Obx(() => AppTextField(label: 'Address', controller: c.address, required: true, serverError: c.error('address'))),
                  ]),
                ],
              ),
              _Section(
                index: 2,
                title: 'Reporting & access',
                children: [
                  Obx(
                    () => Opacity(
                      opacity: c.multiHospital.value ? .5 : 1,
                      child: LookupField(
                        label: 'Cardiologist',
                        value: c.cardiologist.value,
                        enabled: !c.multiHospital.value,
                        hint: c.multiHospital.value ? 'Not used with multi-hospital access' : 'Select cardiologist (optional)',
                        onTap: c.pickCardiologist,
                        onClear: () => c.cardiologist.value = null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFEAECF0)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Obx(
                      () => Column(
                        children: [
                          SwitchTile(
                            title: 'Report limit',
                            subtitle: 'Cap how many ECGs this client can send for cardiologist review (ECG balance).',
                            value: c.reportLimitOn.value,
                            onChanged: (v) => c.reportLimitOn.value = v,
                            trailing: AnimatedSize(
                              duration: const Duration(milliseconds: 200),
                              child: c.reportLimitOn.value
                                  ? SizedBox(
                                      width: 130,
                                      child: TextFormField(
                                        controller: c.reportLimit,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                        decoration: InputDecoration(labelText: 'Limit', errorText: c.error('report_limit')),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                          const Divider(),
                          SwitchTile(
                            title: 'Multi hospital access',
                            subtitle: 'Allow this client to work with more than one hospital and manage its own cardiologists.',
                            value: c.multiHospital.value,
                            onChanged: (v) => c.multiHospital.value = v,
                          ),
                          if (!c.editing) ...[
                            const Divider(),
                            SwitchTile(
                              title: 'Create default staff',
                              subtitle: 'Creates a staff login with the same password and the email ${c.defaultStaffEmail}',
                              value: c.defaultStaff.value,
                              onChanged: (v) => c.defaultStaff.value = v,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (!c.editing)
                _Section(
                  index: 3,
                  title: 'Devices',
                  subtitle: 'Instrument IDs of the Dr. Cardio devices this client uses. You can add more later from Devices.',
                  trailing: OutlinedButton.icon(
                    onPressed: c.addDevice,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add device'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brand,
                      side: const BorderSide(color: AppColors.brand),
                    ),
                  ),
                  children: [
                    Obx(() {
                      final count = c.devices.length; // read here so Obx tracks the list
                      return LayoutBuilder(
                        builder: (context, box) {
                          final cols = box.maxWidth > 700 ? 3 : (box.maxWidth > 440 ? 2 : 1);
                          final w = (box.maxWidth - (cols - 1) * 10) / cols;
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (var i = 0; i < count; i++)
                                SizedBox(
                                  width: w,
                                  child: TextFormField(
                                    controller: c.devices[i],
                                    style: AppTextStyles.mono.copyWith(fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Dr.Cardio/261-A1F3',
                                      errorText: c.error('devices.$i'),
                                      prefixIcon: const Icon(Icons.developer_board_rounded, size: 18, color: AppColors.brand),
                                      suffixIcon: IconButton(
                                        tooltip: 'Remove device',
                                        onPressed: () => c.removeDevice(i),
                                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.dangerText),
                                      ),
                                    ),
                                  ),
                                ).animate().fadeIn(duration: 200.ms).scaleXY(begin: .96, end: 1),
                            ],
                          );
                        },
                      );
                    }),
                  ],
                ),
              _Section(
                index: 4,
                title: 'Integrations',
                subtitle: 'Connect the client\'s own hospital software.',
                children: [
                  Obx(
                    () => AppTextField(
                      label: 'Webhook URL',
                      controller: c.webhook,
                      hint: 'https://…',
                      keyboardType: TextInputType.url,
                      validator: Validators.url,
                      serverError: c.error('webhook_url'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Obx(
                    () => Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFEAECF0)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Column(
                        children: [
                          SwitchTile(
                            title: 'Get Patient API enabled',
                            subtitle: 'Fetch patient details from the client\'s system before recording.',
                            value: c.patientApiOn.value,
                            onChanged: (v) => c.patientApiOn.value = v,
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            child: c.patientApiOn.value
                                ? Padding(
                                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                                    child: AppTextField(
                                      label: 'Get patient URL',
                                      controller: c.patientUrl,
                                      hint: 'https://…',
                                      keyboardType: TextInputType.url,
                                      validator: Validators.url,
                                      serverError: c.error('get_patient_url'),
                                    ),
                                  )
                                : const SizedBox(width: double.infinity),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SecondaryButton(label: 'Cancel', onPressed: () => closeRoute(null, AppRoutes.clients)),
                    const SizedBox(width: 10),
                    Obx(
                      () => PrimaryButton(
                        label: c.editing ? 'Save changes' : 'Save client',
                        icon: Icons.check_rounded,
                        loading: c.saving.value,
                        onPressed: c.save,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  static Widget _row(BuildContext context, List<Widget> children) {
    if (Responsive.isPhone(context)) {
      return Column(
        children: [for (final w in children) Padding(padding: const EdgeInsets.only(bottom: 14), child: w)],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 16), Expanded(child: children[i])],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.index, required this.title, required this.children, this.subtitle, this.trailing});
  final int index;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                margin: const EdgeInsets.only(right: 12, top: 1),
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle),
                child: Text(
                  '${index + 1}',
                  style: AppTextStyles.body(size: 12.5, weight: FontWeight.w700, color: Colors.white),
                ),
              ),
              Expanded(child: SectionTitle(title, subtitle: subtitle)),
              ?trailing,
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, delay: (60 * index).ms).slideY(begin: .04, end: 0);
  }
}
