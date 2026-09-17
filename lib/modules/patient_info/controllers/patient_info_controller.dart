import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/bluetooth/bluetooth_service.dart';
import '../../../core/services/ecg/ecg_data.dart';
import '../../../core/services/storage_service.dart';
import '../../../data/models/patient_model.dart';
import '../../../routes/app_routes.dart';
import '../../live_ecg/controllers/live_ecg_controller.dart';

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

  /// Only Full name and Gender are mandatory — Patient ID and Age are
  /// optional. Starts unselected (no default) rather than pre-picking
  /// "Male", since it's now a required field the clinician must actively
  /// choose rather than one that could silently go unnoticed.
  final RxnString gender = RxnString();

  /// True when opened to edit a record already loaded elsewhere (Load
  /// Data's "change patient data" option), rather than for a fresh
  /// recording — [Get.arguments] is a [PatientModel] to prefill instead of
  /// null. `continueToRecording()` branches on this to write the edited
  /// patient straight into the still-alive LiveEcgController instead of
  /// resetting acquisition state and navigating into a new live recording.
  bool isEditMode = false;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is PatientModel) {
      isEditMode = true;
      idController.text = args.patientId;
      nameController.text = args.name;
      ageController.text = args.age;
      heightController.text = args.height;
      weightController.text = args.weight;
      bpController.text = args.bloodPressure;
      medicationsController.text = args.medications;
      commentsController.text = args.comments;
      // Guards against a legacy/imported record whose stored sex isn't
      // exactly one of the dropdown's own options (e.g. different casing)
      // — feeding that straight into DropdownButtonFormField's value
      // crashes it ("there should be exactly one item with this value"),
      // which would make this whole screen fail to open silently.
      if (_genderOptions.contains(args.sex)) gender.value = args.sex;
    }
  }

  static const _genderOptions = ['Male', 'Female', 'Other'];

  void setGender(String value) => gender.value = value;

  void continueToRecording() {
    if (!formKey.currentState!.validate()) return;

    final patient = PatientModel(
      patientId: idController.text.trim(),
      name: nameController.text.trim(),
      age: ageController.text.trim(),
      sex: gender.value!,
      height: heightController.text.trim(),
      weight: weightController.text.trim(),
      bloodPressure: bpController.text.trim(),
      medications: medicationsController.text.trim(),
      comments: commentsController.text.trim(),
    );

    if (isEditMode) {
      // Writing straight into the caller's controller (same proven
      // Get.find<T>() pattern used throughout this app) rather than
      // returning a typed result through Get.back()/Get.toNamed<T>() —
      // this screen is only ever pushed on top of Live ECG for editing,
      // so it's still alive and registered underneath.
      if (Get.isRegistered<LiveEcgController>()) {
        Get.find<LiveEcgController>().patient.value = patient;
      }
      Get.back();
      return;
    }

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
