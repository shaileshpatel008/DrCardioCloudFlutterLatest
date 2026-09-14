import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/ecg_record_model.dart';
import '../../../data/repositories/ecg_repository.dart';

/// Port of `LoadDataActivity`: search + list of recordings stored on this
/// device.
class LoadDataController extends GetxController {
  LoadDataController({EcgRepository? repository}) : _repository = repository ?? EcgRepository();

  final EcgRepository _repository;
  final searchController = TextEditingController();

  final RxList<EcgRecordModel> records = <EcgRecordModel>[].obs;
  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    reload();
  }

  Future<void> reload() async {
    isLoading.value = true;
    records.assignAll(await _repository.allRecords());
    isLoading.value = false;
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      await reload();
      return;
    }
    records.assignAll(await _repository.search(query.trim()));
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }
}
