import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/network_models.dart';
import '../models/paged.dart';

/// Query shared by every paginated list.
class ListQuery {
  const ListQuery({this.page = 1, this.perPage = 10, this.search = '', this.sort, this.dir = 'desc', this.extra = const {}});

  final int page;
  final int perPage;
  final String search;
  final String? sort;
  final String dir;
  final Map<String, dynamic> extra;

  Map<String, dynamic> toMap() => {
        'page': page,
        'per_page': perPage,
        'search': search.trim(),
        'sort': sort,
        'dir': dir,
        ...extra,
      };
}

class ClientRepository {
  final _api = DioClient.instance;

  Future<Paged<ClientModel>> list(ListQuery q) async =>
      Paged.fromJson(await _api.get(ApiConstants.clients, query: q.toMap()), ClientModel.fromJson);

  Future<ClientModel> detail(int id) async => ClientModel.fromJson(asMap((await _api.get(ApiConstants.client(id)))['data']));

  Future<String> create(Map<String, dynamic> body) async =>
      asStringOr((await _api.post(ApiConstants.clients, data: body))['message'], 'Client saved.');

  Future<String> update(int id, Map<String, dynamic> body) async =>
      asStringOr((await _api.put(ApiConstants.client(id), data: body))['message'], 'Client updated.');

  Future<String> delete(int id) async => asStringOr((await _api.delete(ApiConstants.client(id)))['message'], 'Client deleted.');

  Future<Paged<StaffModel>> staff(int clientUserId, ListQuery q) async =>
      Paged.fromJson(await _api.get(ApiConstants.clientStaff(clientUserId), query: q.toMap()), StaffModel.fromJson);
}

class StaffRepository {
  final _api = DioClient.instance;

  Future<Paged<StaffModel>> adminList(ListQuery q) async =>
      Paged.fromJson(await _api.get(ApiConstants.adminStaffs, query: q.toMap()), StaffModel.fromJson);

  Future<Paged<StaffModel>> myList(ListQuery q) async =>
      Paged.fromJson(await _api.get(ApiConstants.myStaffs, query: q.toMap()), StaffModel.fromJson);

  Future<StaffModel> detail(int id) async => StaffModel.fromJson(asMap((await _api.get(ApiConstants.staffMember(id)))['data']));

  Future<String> create(Map<String, dynamic> body) async =>
      asStringOr((await _api.post(ApiConstants.staff, data: body))['message'], 'Staff member added.');

  Future<String> update(int id, Map<String, dynamic> body) async =>
      asStringOr((await _api.put(ApiConstants.staffMember(id), data: body))['message'], 'Staff member updated.');

  Future<String> delete(int id) async =>
      asStringOr((await _api.delete(ApiConstants.staffMember(id)))['message'], 'Staff member deleted.');
}

class CardiologistRepository {
  final _api = DioClient.instance;

  Future<Paged<CardiologistModel>> list(ListQuery q) async =>
      Paged.fromJson(await _api.get(ApiConstants.cardiologists, query: q.toMap()), CardiologistModel.fromJson);

  Future<CardiologistModel> detail(int id) async =>
      CardiologistModel.fromJson(asMap((await _api.get(ApiConstants.cardiologist(id)))['data']));

  Future<String> create(Map<String, dynamic> body) async =>
      asStringOr((await _api.post(ApiConstants.cardiologists, data: body))['message'], 'Cardiologist saved.');

  Future<String> update(int id, Map<String, dynamic> body) async =>
      asStringOr((await _api.put(ApiConstants.cardiologist(id), data: body))['message'], 'Cardiologist updated.');

  Future<String> delete(int id) async =>
      asStringOr((await _api.delete(ApiConstants.cardiologist(id)))['message'], 'Cardiologist deleted.');
}

class DeviceRepository {
  final _api = DioClient.instance;

  Future<Paged<DeviceModel>> list(ListQuery q) async =>
      Paged.fromJson(await _api.get(ApiConstants.devices, query: q.toMap()), DeviceModel.fromJson);

  Future<String> create(int hospitalId, String instrumentId) async => asStringOr(
      (await _api.post(ApiConstants.devices, data: {'hospital_id': hospitalId, 'intrument_id': instrumentId.trim()}))['message'],
      'Device saved.');

  Future<String> update(int id, int hospitalId, String instrumentId) async => asStringOr(
      (await _api.put(ApiConstants.device(id), data: {'hospital_id': hospitalId, 'intrument_id': instrumentId.trim()}))['message'],
      'Device updated.');

  Future<String> delete(int id) async => asStringOr((await _api.delete(ApiConstants.device(id)))['message'], 'Device deleted.');
}

class OemUserRepository {
  final _api = DioClient.instance;

  Future<Paged<OemUserModel>> list(ListQuery q) async =>
      Paged.fromJson(await _api.get(ApiConstants.oemUsers, query: q.toMap()), OemUserModel.fromJson);

  Future<OemUserModel> detail(int id) async => OemUserModel.fromJson(asMap((await _api.get(ApiConstants.oemUser(id)))['data']));

  Future<String> create(Map<String, dynamic> body) async =>
      asStringOr((await _api.post(ApiConstants.oemUsers, data: body))['message'], 'OEM user saved.');

  Future<String> update(int id, Map<String, dynamic> body) async =>
      asStringOr((await _api.put(ApiConstants.oemUser(id), data: body))['message'], 'OEM user updated.');

  Future<String> delete(int id) async => asStringOr((await _api.delete(ApiConstants.oemUser(id)))['message'], 'OEM user deleted.');
}

class LookupRepository {
  final _api = DioClient.instance;

  Future<List<LookupItem>> _items(String path, [Map<String, dynamic>? query]) async =>
      asMapList((await _api.get(path, query: query))['data']).map(LookupItem.fromJson).toList();

  Future<List<LookupItem>> hospitals() => _items(ApiConstants.lookupHospitals);
  Future<List<LookupItem>> cardiologists() => _items(ApiConstants.lookupCardiologists);
  Future<List<LookupItem>> staffs(int hospitalId) => _items(ApiConstants.lookupStaffs, {'hospital_id': hospitalId});
  Future<List<LookupItem>> devices(int hospitalId) => _items(ApiConstants.lookupDevices, {'hospital_id': hospitalId});
}

class NotificationRepository {
  final _api = DioClient.instance;

  Future<({List<NotificationItem> items, int unread})> latest() async {
    final res = await _api.get(ApiConstants.notifications);
    return (
      items: asMapList(res['data']).map(NotificationItem.fromJson).toList(),
      unread: asIntOr(res['unread_total']),
    );
  }

  Future<void> read(int id) => _api.post(ApiConstants.notificationRead(id));
  Future<void> readAll() => _api.post(ApiConstants.notificationsReadAll);
}

class ExportRepository {
  final _api = DioClient.instance;

  Future<int> count(Map<String, dynamic> filters) async =>
      asIntOr(asMap((await _api.get(ApiConstants.exportEcgCount, query: filters))['data'])['total']);

  /// type: 'pdf' (zip of ECG + report PDFs) or 'csv' (zip of CSV files).
  Future<({List<int> bytes, String? fileName})> ecg(String type, Map<String, dynamic> filters) async {
    final body = <String, dynamic>{'type': type};
    filters.forEach((k, v) {
      if (v != null && !(v is String && v.isEmpty)) body[k] = v;
    });
    return _api.download(ApiConstants.exportEcg, data: body);
  }

  Future<({List<int> bytes, String? fileName})> ecgCounts(String month, String year) =>
      _api.download(ApiConstants.exportEcgCounts, data: {'month': month, 'year': year});
}

class ProfileRepository {
  final _api = DioClient.instance;

  Future<Map<String, dynamic>> get() async => asMap((await _api.get(ApiConstants.profile))['data']);

  /// Multipart so the cardiologist logo / signature and the OEM logo can be uploaded.
  Future<({String message, Map<String, dynamic> data})> update(
    Map<String, dynamic> fields, {
    ({List<int> bytes, String name})? logo,
    ({List<int> bytes, String name})? signature,
  }) async {
    final form = FormData.fromMap({
      ...fields..removeWhere((k, v) => v == null),
      if (logo != null) 'logo': MultipartFile.fromBytes(logo.bytes, filename: logo.name),
      if (signature != null) 'signature': MultipartFile.fromBytes(signature.bytes, filename: signature.name),
    });
    final res = await _api.post(ApiConstants.profile, data: form);
    return (message: asStringOr(res['message'], 'Profile updated.'), data: asMap(res['data']));
  }

  Future<void> deleteLogo() => _api.delete(ApiConstants.profileLogo);
  Future<void> deleteSignature() => _api.delete(ApiConstants.profileSignature);
}
