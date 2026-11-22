import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/models/network_models.dart';
import '../../../data/repositories/network_repository.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// Cardiologist profile (web "Cardiologist Info") — without the password.
/// Returns 'edit' / 'delete' when the user picks those actions.
class CardiologistViewPanel extends StatelessWidget {
  const CardiologistViewPanel({super.key, required this.id});
  final int id;

  static Future<String?> open(int id) => AppDialogs.showSidePanel<String>(CardiologistViewPanel(id: id), width: 460);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CardiologistModel>(
      future: CardiologistRepository().detail(id),
      builder: (context, snap) {
        Widget body;
        if (snap.connectionState != ConnectionState.done) {
          body = const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
        } else if (snap.hasError) {
          final e = snap.error;
          body = ErrorState(message: e is ApiException ? e.message : 'Couldn\'t load this cardiologist.');
        } else {
          final c = snap.data!;
          body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              InitialsAvatar(c.name, size: 56, radius: 16, tintIndex: 1),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.name, style: AppTextStyles.h2),
                  Text('Updated ${Fmt.date(c.updatedAt)}', style: AppTextStyles.caption),
                ]),
              ),
            ]),
            const SizedBox(height: 22),
            InfoTile(label: 'Email', value: c.email),
            const SizedBox(height: 16),
            InfoTile(label: 'Phone number', value: c.phoneNumber),
            const SizedBox(height: 16),
            InfoTile(label: 'Address', value: c.address),
            const SizedBox(height: 22),
            Text('Linked hospitals', style: AppTextStyles.label),
            const SizedBox(height: 8),
            if (c.clients.isEmpty)
              Text('Not linked to a client yet. Link one from the client\'s form.', style: AppTextStyles.muted)
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final h in c.clients)
                  Chip(
                    avatar: const Icon(Icons.apartment_rounded, size: 16, color: AppColors.brand),
                    label: Text(h.hospitalName),
                    backgroundColor: AppColors.brandTint,
                    side: BorderSide.none,
                  ),
              ]),
          ]);
        }
        return PanelScaffold(
          title: 'Cardiologist',
          body: body,
          footer: Row(children: [
            Expanded(child: SecondaryButton(label: 'Delete', icon: Icons.delete_outline_rounded, danger: true, onPressed: () => Get.back(result: 'delete'))),
            const SizedBox(width: 10),
            Expanded(child: PrimaryButton(label: 'Edit', icon: Icons.edit_outlined, onPressed: () => Get.back(result: 'edit'))),
          ]),
        );
      },
    );
  }
}
