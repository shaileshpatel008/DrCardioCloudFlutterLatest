import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../controllers/load_data_controller.dart';

class LoadDataView extends GetView<LoadDataController> {
  const LoadDataView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Load Data')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: TextField(
              controller: controller.searchController,
              onChanged: controller.search,
              decoration: const InputDecoration(
                hintText: 'Search by name or ID…',
                prefixIcon: Icon(Icons.search, color: AppColors.muted2),
              ),
            ),
          ),
          Obx(() => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${controller.records.length} recordings stored on this device',
                      style: const TextStyle(color: AppColors.muted2, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              )),
          const SizedBox(height: 8),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) return const Center(child: CircularProgressIndicator());
              if (controller.records.isEmpty) {
                return const Center(child: Text('No matching recordings.', style: TextStyle(color: AppColors.muted)));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: controller.records.length,
                separatorBuilder: (_, __) => const SizedBox(height: 9),
                itemBuilder: (context, index) {
                  final record = controller.records[index];
                  return ListTile(
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: AppColors.brandRedTint, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.description_outlined, color: AppColors.brandRed, size: 18),
                    ),
                    title: Text(record.patient.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: Text(
                      '${record.patient.patientId} · ${DateFormat('d MMM, h:mm a').format(record.dateTime)}',
                      style: const TextStyle(color: AppColors.muted2, fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.muted2),
                    // Port of `LoadDataActivity`'s item click: opens the
                    // recording in the live ECG screen (not the PDF)
                    // filled with its captured 12-lead data, with a
                    // "change patient data" option and a working Save that
                    // regenerates the report — same screen `NewEcgActivity`
                    // uses via `checkFromLoadData()`, not a read-only viewer.
                    onTap: () => Get.toNamed(AppRoutes.liveEcg, arguments: record),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
