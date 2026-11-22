import '../../../core/base/paged_list_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/models/network_models.dart';
import '../../../data/models/paged.dart';
import '../../../data/repositories/network_repository.dart';
import '../widgets/oem_user_form.dart';

class OemUsersController extends PagedListController<OemUserModel> {
  final _repo = OemUserRepository();

  @override
  Future<Paged<OemUserModel>> fetch(query) => _repo.list(query);

  Future<void> add() async {
    if (await OemUserForm.open()) load(toPage: 1);
  }

  Future<void> edit(OemUserModel u) async {
    if (await OemUserForm.open(existing: u)) refreshList();
  }

  Future<void> view(OemUserModel u) async {
    final action = await OemUserForm.open(existing: u, viewOnly: true);
    if (action) refreshList();
  }

  Future<void> delete(OemUserModel u) async {
    final ok = await AppDialogs.confirm(
      title: 'Delete ${u.name}?',
      message: '${u.email} will no longer be able to sign in. Their clients and cardiologists stay in the system.',
    );
    if (!ok) return;
    try {
      AppToast.success(await _repo.delete(u.id));
      refreshList();
    } on ApiException catch (e) {
      AppToast.error(e.message);
    }
  }
}
