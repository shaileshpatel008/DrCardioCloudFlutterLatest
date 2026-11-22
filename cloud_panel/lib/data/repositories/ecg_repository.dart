import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/dashboard_model.dart';
import '../models/ecg_filters.dart';
import '../models/ecg_record_model.dart';
import '../models/paged.dart';

class EcgRepository {
  final _api = DioClient.instance;

  Future<DashboardData> dashboard() async {
    final res = await _api.get(ApiConstants.dashboard);
    return DashboardData.fromJson(asMap(res['data']));
  }

  Future<Paged<EcgRecord>> list(EcgFilters filters, {int page = 1, int perPage = 10, String sort = 'date', String dir = 'desc'}) async {
    final res = await _api.get(ApiConstants.ecgRecords, query: {
      ...filters.toQuery(),
      'page': page,
      'per_page': perPage,
      'sort': sort,
      'dir': dir,
    });
    return Paged.fromJson(res, EcgRecord.fromJson);
  }

  Future<EcgSummary> summary(EcgFilters filters) async {
    final res = await _api.get(ApiConstants.ecgSummary, query: filters.toQuery(includeStatus: false));
    return EcgSummary.fromJson(asMap(res['data']));
  }

  Future<EcgRecord> detail(int id) async {
    final res = await _api.get(ApiConstants.ecgRecord(id));
    return EcgRecord.fromJson(asMap(res['data']));
  }

  Future<String> delete(int id) async {
    final res = await _api.delete(ApiConstants.ecgRecord(id));
    return asStringOr(res['message'], 'ECG record deleted.');
  }

  Future<String> reassign(int id, int cardiologistId) async {
    final res = await _api.post(ApiConstants.ecgReassign(id), data: {'cardiologist_id': cardiologistId});
    return asStringOr(res['message'], 'ECG re-assigned.');
  }

  Future<String> assign(int id) async {
    final res = await _api.post(ApiConstants.ecgAssign(id));
    return asStringOr(res['message'], 'ECG sent to the cardiologist.');
  }

  Future<({EcgRecord record, List<ReportTemplate> templates})> diagnoseForm(int id) async {
    final res = await _api.get(ApiConstants.ecgDiagnose(id));
    final data = asMap(res['data']);
    return (
      record: EcgRecord.fromJson(asMap(data['record'])),
      templates: asMapList(data['templates']).map(ReportTemplate.fromJson).toList(),
    );
  }

  /// [publish] false = Save draft (stays "requested"), true = Publish (reported).
  Future<({String message, EcgRecord? record})> diagnose(int id, {required bool publish, required Map<String, dynamic> fields}) async {
    final res = await _api.post(ApiConstants.ecgDiagnose(id), data: {
      'action': publish ? 'publish' : 'draft',
      ...fields,
    });
    final data = res['data'];
    return (
      message: asStringOr(res['message'], publish ? 'Report published.' : 'Draft saved.'),
      record: data is Map ? EcgRecord.fromJson(asMap(data)) : null,
    );
  }
}
