import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/bluetooth/bluetooth_service.dart';
import '../../../core/services/ecg/ecg_data.dart';
import '../../../core/services/storage_service.dart';
import '../../../data/models/patient_model.dart';
import '../../../routes/app_routes.dart';

class PatientInfoController extends GetxController {
  final formKey = GlobalKey<FormState>();
  final idController = TextEditingController();
  final nameController = TextEditingController();
  final ageController = TextEditingController();
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  final bpController = TextEditingController();
  final medicationsController = TextEditingController();
  final commentsController = TextEditingController();

  final RxString sex = 'Male'.obs;

  void setSex(String value) => sex.value = value;

  void continueToRecording() {
    if (!formKey.currentState!.validate()) return;

    final patient = PatientModel(
      patientId: idController.text.trim(),
      name: nameController.text.trim(),
      age: ageController.text.trim(),
      sex: sex.value,
      height: heightController.text.trim(),
      weight: weightController.text.trim(),
      bloodPressure: bpController.text.trim(),
      medications: medicationsController.text.trim(),
      comments: commentsController.text.trim(),
    );

    final ecg = EcgData.instance;
    ecg.resetEcgData();
    ecg.initDataWithLength(maxReadSeconds: 300);
    ecg.patientId = patient.patientId;
    ecg.patientName = patient.name;
    ecg.patientAge = patient.age;
    ecg.patientSex = patient.sex;
    ecg.deviceName = Get.find<BluetoothService>().connectedDeviceName.value;
    ecg.patientDeviceId = StorageService.instance.savedDeviceName;

    Get.offNamed(AppRoutes.liveEcg, arguments: patient);
  }

  @override
  void onClose() {
    idController.dispose();
    nameController.dispose();
    ageController.dispose();
    heightController.dispose();
    weightController.dispose();
    bpController.dispose();
    medicationsController.dispose();
    commentsController.dispose();
    super.onClose();
  }
}
