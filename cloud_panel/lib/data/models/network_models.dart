import '../../core/utils/json_utils.dart';

/// A client account (hospital / lab / clinic). `id` is the client's user id
/// (what the API routes use); `clientId` is the clients-table id that
/// devices, staff and ECG filters reference.
class ClientModel {
  ClientModel({
    required this.id,
    required this.clientId,
    required this.name,
    required this.email,
    required this.hospitalName,
    this.phoneNumber,
    this.doctorName,
    this.address,
    this.cardiologistId,
    this.cardiologistName,
    this.reportLimitEnabled = false,
    this.reportLimit = 0,
    this.multiHospitalAccess = false,
    this.webhookUrl,
    this.getPatientApiEnabled = false,
    this.getPatientUrl,
    this.staffCount,
    this.devices = const [],
    this.createdAt,
  });

  final int id;
  final int clientId;
  final String name;
  final String email;
  final String? phoneNumber;
  final String hospitalName;
  final String? doctorName;
  final String? address;
  final int? cardiologistId;
  final String? cardiologistName;
  final bool reportLimitEnabled;
  final int reportLimit;
  final bool multiHospitalAccess;
  final String? webhookUrl;
  final bool getPatientApiEnabled;
  final String? getPatientUrl;
  final int? staffCount;
  final List<DeviceModel> devices;
  final DateTime? createdAt;

  /// ECG balance shown in the list: null means unlimited.
  int? get ecgBalance => reportLimitEnabled ? reportLimit : null;

  factory ClientModel.fromJson(Map<String, dynamic> j) => ClientModel(
        id: asIntOr(j['id']),
        clientId: asIntOr(j['client_id']),
        name: asStringOr(j['name']),
        email: asStringOr(j['email']),
        phoneNumber: asString(j['phone_number']),
        hospitalName: asStringOr(j['hospital_name'], '—'),
        doctorName: asString(j['doctor_name']),
        address: asString(j['address']),
        cardiologistId: asInt(j['cardiologist_id']),
        cardiologistName: asString(j['cardiologist_name']),
        reportLimitEnabled: asBool(j['report_limit_enabled']),
        reportLimit: asIntOr(j['report_limit']),
        multiHospitalAccess: asBool(j['multi_hospital_access']),
        webhookUrl: asString(j['webhook_url']),
        getPatientApiEnabled: asBool(j['get_patient_api_enabled']),
        getPatientUrl: asString(j['get_patient_url']),
        staffCount: asInt(j['staff_count']),
        devices: asMapList(j['devices']).map(DeviceModel.fromJson).toList(),
        createdAt: asDate(j['created_at']),
      );
}

class StaffModel {
  StaffModel({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    this.clientId,
    this.clientName,
    this.clientUserId,
    this.cardiologistId,
    this.cardiologistName,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String email;
  final String? phoneNumber;
  final int? clientId;
  final String? clientName;
  final int? clientUserId;
  final int? cardiologistId;
  final String? cardiologistName;
  final DateTime? updatedAt;

  factory StaffModel.fromJson(Map<String, dynamic> j) => StaffModel(
        id: asIntOr(j['id']),
        name: asStringOr(j['name'], '—'),
        email: asStringOr(j['email']),
        phoneNumber: asString(j['phone_number']),
        clientId: asInt(j['client_id']),
        clientName: asString(j['client_name']),
        clientUserId: asInt(j['client_user_id']),
        cardiologistId: asInt(j['cardiologist_id']),
        cardiologistName: asString(j['cardiologist_name']),
        updatedAt: asDate(j['updated_at']),
      );
}

class CardiologistModel {
  CardiologistModel({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    this.address,
    this.clientsCount = 0,
    this.clients = const [],
    this.updatedAt,
  });

  final int id;
  final String name;
  final String email;
  final String? phoneNumber;
  final String? address;
  final int clientsCount;
  final List<({int id, String hospitalName})> clients;
  final DateTime? updatedAt;

  factory CardiologistModel.fromJson(Map<String, dynamic> j) => CardiologistModel(
        id: asIntOr(j['id']),
        name: asStringOr(j['name'], '—'),
        email: asStringOr(j['email']),
        phoneNumber: asString(j['phone_number']),
        address: asString(j['address']),
        clientsCount: asIntOr(j['clients_count'], asMapList(j['clients']).length),
        clients: asMapList(j['clients'])
            .map((c) => (id: asIntOr(c['id']), hospitalName: asStringOr(c['hospital_name'], '—')))
            .toList(),
        updatedAt: asDate(j['updated_at']),
      );
}

class DeviceModel {
  DeviceModel({required this.id, required this.instrumentId, this.hospitalId, this.hospitalName, this.clientUserId, this.updatedAt});

  final int id;
  final String instrumentId;
  final int? hospitalId;
  final String? hospitalName;
  final int? clientUserId;
  final DateTime? updatedAt;

  factory DeviceModel.fromJson(Map<String, dynamic> j) => DeviceModel(
        id: asIntOr(j['id']),
        instrumentId: asStringOr(j['instrument_id'], '—'),
        hospitalId: asInt(j['hospital_id']),
        hospitalName: asString(j['hospital_name']),
        clientUserId: asInt(j['client_user_id']),
        updatedAt: asDate(j['updated_at']),
      );
}

class OemUserModel {
  OemUserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    this.clientsCount = 0,
    this.cardiologistsCount,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String email;
  final String? phoneNumber;
  final int clientsCount;
  final int? cardiologistsCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory OemUserModel.fromJson(Map<String, dynamic> j) => OemUserModel(
        id: asIntOr(j['id']),
        name: asStringOr(j['name'], '—'),
        email: asStringOr(j['email']),
        phoneNumber: asString(j['phone_number']),
        clientsCount: asIntOr(j['clients_count']),
        cardiologistsCount: asInt(j['cardiologists_count']),
        createdAt: asDate(j['created_at']),
        updatedAt: asDate(j['updated_at']),
      );
}

class NotificationItem {
  NotificationItem({required this.id, required this.title, this.date, this.createdAt});

  final int id;
  final String title;
  final String? date;
  final DateTime? createdAt;

  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
        id: asIntOr(j['id']),
        title: asStringOr(j['title'], 'Notification'),
        date: asString(j['date']),
        createdAt: asDate(j['created_at']),
      );
}
