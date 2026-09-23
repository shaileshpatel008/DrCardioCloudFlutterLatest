import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../theme/app_colors.dart';
import '../controllers/help_controller.dart';

class HelpView extends GetView<HelpController> {
  const HelpView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text('Help', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 18),
        const _FaqTile(
          question: 'The device won’t connect',
          answer: 'Make sure Bluetooth is turned on, the device is charged, and it’s within a metre of your phone. '
              'On Android 12+, grant the Nearby Devices permission when asked.',
        ),
        const _FaqTile(
          question: 'A lead shows as disconnected during recording',
          answer: 'Check that the corresponding electrode is firmly attached to the skin — a loose electrode is the most common cause.',
        ),
        const _FaqTile(
          question: 'A recording didn’t upload',
          answer: 'It stays saved on this device and queues automatically. Open Settings → Manage Offline Reports to see pending '
              'uploads or retry manually once you’re back online.',
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              const Icon(Icons.replay_circle_filled_outlined, color: AppColors.brandRed),
              const SizedBox(width: 12),
              const Expanded(child: Text('Watch the getting-started walkthrough again', style: TextStyle(fontWeight: FontWeight.w600))),
              TextButton(onPressed: controller.replayWalkthrough, child: const Text('Replay')),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Port of `helpDialog()` — the old app's Help tab was this
        // Call/WhatsApp prompt on its own; here it sits alongside the FAQ
        // content as a straightforward "still stuck? contact us" card.
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Still stuck?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              const SizedBox(height: 3),
              const Text(
                'Call or chat with our support team',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: controller.callSupport,
                      icon: const Icon(Icons.call_outlined, size: 18),
                      label: const Text('Call'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.brandRed,
                        side: const BorderSide(color: AppColors.brandRed),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: controller.chatOnWhatsApp,
                      icon: const Icon(Icons.chat_outlined, size: 18),
                      label: const Text('WhatsApp'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF25D366),
                        side: const BorderSide(color: Color(0xFF25D366)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Kavitul Technologies Pvt. Ltd.\nsupport@drcardio.in',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted2, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});
  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(question, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(answer, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5))],
        ),
      ),
    );
  }
}
