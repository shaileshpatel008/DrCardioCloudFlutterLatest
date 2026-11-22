<?php

namespace App\Http\Controllers\API\V2;

use App\Http\Controllers\API\V2\Concerns\NormalizesCheckboxes;
use App\Http\Controllers\ClientController as WebClientController;
use App\Models\Client;
use App\Models\ClientCardiologist;
use App\Models\ClientStaff;
use App\Models\Device;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ClientController extends ApiController
{
    use NormalizesCheckboxes;

    private const CHECKBOXES = ['report_limit_enabled', 'multi_hospital_access', 'create_default_staff', 'get_patient_api_enabled'];

    /** GET /api/v2/clients?page&per_page&search&cardiologist_id&sort=name|email|hospital|doctor|date&dir */
    public function index(Request $request)
    {
        $query = User::select(
            'users.id as user_id', 'users.name', 'users.email', 'users.phone_number',
            'clients.id as client_id', 'clients.hospital_name', 'clients.doctor_name', 'clients.address',
            'clients.report_limit_enabled', 'clients.report_limit', 'clients.multi_hospital_access',
            'clients.created_at',
            DB::raw('(SELECT cc.cardiologist_id FROM client_cardiologist cc WHERE cc.client_id = users.id ORDER BY cc.id LIMIT 1) AS cardiologist_id'),
            DB::raw('(SELECT cu.name FROM client_cardiologist cc JOIN users cu ON cu.id = cc.cardiologist_id WHERE cc.client_id = users.id ORDER BY cc.id LIMIT 1) AS cardiologist_name')
        )
            ->join('clients', 'clients.user_id', '=', 'users.id')
            ->join('role_user', 'role_user.user_id', '=', 'users.id')
            ->join('roles', 'role_user.role_id', '=', 'roles.id')
            ->where('roles.name', '=', 'client')
            ->whereNull('clients.deleted_at');

        $this->scopeByParent($query, 'clients.parent_user_id');

        if ($cardiologistId = $request->input('cardiologist_id')) {
            $query->whereExists(function ($q) use ($cardiologistId) {
                $q->select(DB::raw(1))->from('client_cardiologist')
                    ->whereColumn('client_cardiologist.client_id', 'users.id')
                    ->where('client_cardiologist.cardiologist_id', $cardiologistId);
            });
        }

        if ($search = $this->searchTerm($request)) {
            $query->where(function ($q) use ($search) {
                $q->orWhere('clients.hospital_name', 'like', "%{$search}%")
                    ->orWhere('users.name', 'like', "%{$search}%")
                    ->orWhere('users.email', 'like', "%{$search}%")
                    ->orWhere('users.phone_number', 'like', "%{$search}%")
                    ->orWhere('clients.doctor_name', 'like', "%{$search}%");
            });
        }

        return $this->paginate($query, $request, [
            'name' => 'users.name',
            'email' => 'users.email',
            'hospital' => 'clients.hospital_name',
            'doctor' => 'clients.doctor_name',
            'date' => 'clients.created_at',
        ], 'date', fn ($r) => [
            'id' => $r->user_id,
            'client_id' => $r->client_id,
            'name' => $r->name,
            'email' => $r->email,
            'phone_number' => $r->phone_number,
            'hospital_name' => $r->hospital_name,
            'doctor_name' => $r->doctor_name,
            'address' => $r->address,
            'cardiologist_id' => $r->cardiologist_id,
            'cardiologist_name' => $r->cardiologist_name,
            'report_limit_enabled' => (int) $r->report_limit_enabled === 1,
            'report_limit' => (int) $r->report_limit,
            'ecg_balance' => (int) $r->report_limit_enabled === 1 ? (int) $r->report_limit : null,
            'multi_hospital_access' => (int) $r->multi_hospital_access === 1,
            'created_at' => $this->iso($r->created_at),
            'created_at_display' => $this->display($r->created_at),
        ]);
    }

    /** GET /api/v2/clients/{user} — profile, settings and devices (never the password). */
    public function show(User $user)
    {
        $client = Client::where('user_id', $user->id)->first();
        if (! $client || ! $this->ownsClient($client)) {
            return $this->fail('Client not found.', 404);
        }

        $link = ClientCardiologist::where('client_id', $user->id)->first();
        $cardiologist = $link ? User::find($link->cardiologist_id) : null;

        return $this->ok([
            'id' => $user->id,
            'client_id' => $client->id,
            'name' => $user->name,
            'email' => $user->email,
            'phone_number' => $user->phone_number,
            'hospital_name' => $client->hospital_name,
            'doctor_name' => $client->doctor_name,
            'address' => $client->address,
            'cardiologist_id' => $cardiologist?->id,
            'cardiologist_name' => $cardiologist?->name,
            'report_limit_enabled' => (int) $client->report_limit_enabled === 1,
            'report_limit' => (int) $client->report_limit,
            'multi_hospital_access' => (int) $client->multi_hospital_access === 1,
            'webhook_url' => $client->webhook_url,
            'get_patient_api_enabled' => (int) $client->get_patient_api_enabled === 1,
            'get_patient_url' => $client->get_patient_url,
            'created_at' => $this->iso($client->created_at),
            'staff_count' => ClientStaff::where('client_id', $client->id)->count(),
            'devices' => Device::where('client_id', $client->id)
                ->orderBy('intrument_id')
                ->get(['id', 'intrument_id', 'updated_at'])
                ->map(fn ($d) => ['id' => $d->id, 'instrument_id' => $d->intrument_id, 'updated_at' => $this->iso($d->updated_at)]),
        ]);
    }

    /**
     * POST /api/v2/clients
     * {cardiologist, name, email, password, password_confirmation, hospital_name, address,
     *  doctor_name, phone_number, report_limit_enabled, report_limit, multi_hospital_access,
     *  create_default_staff, devices[], webhook_url, get_patient_api_enabled, get_patient_url}
     */
    public function store(Request $request)
    {
        $this->normalizeCheckboxes($request, self::CHECKBOXES);

        // Validate every field in one pass (same rules as the web form, plus
        // the device list) so the app can show all errors at once.
        $this->cleanDevices($request, [
            'name' => 'required',
            'email' => 'required|email|unique:users',
            'password' => 'required|min:6|confirmed',
            'hospital_name' => 'required',
            'address' => 'required',
            'doctor_name' => 'required',
            'phone_number' => 'required',
        ]);

        $response = app(WebClientController::class)->store($request);

        return $this->fromWeb($response, 'Client saved successfully.');
    }

    /** POST|PUT /api/v2/clients/{user} — password optional (blank keeps the current one). */
    public function update(Request $request, User $user)
    {
        $client = Client::where('user_id', $user->id)->first();
        if (! $client || ! $this->ownsClient($client)) {
            return $this->fail('Client not found.', 404);
        }
        if ($request->filled('password')) {
            $request->validate(['password' => 'min:6|confirmed']);
        }

        $this->normalizeCheckboxes($request, self::CHECKBOXES);
        $response = app(WebClientController::class)->update($user, $request);

        return $this->fromWeb($response, 'Client updated successfully.');
    }

    /** DELETE /api/v2/clients/{user} */
    public function destroy(User $user)
    {
        $client = Client::where('user_id', $user->id)->first();
        if (! $client || ! $this->ownsClient($client)) {
            return $this->fail('Client not found.', 404);
        }

        return $this->fromWeb(app(WebClientController::class)->delete($user), 'Client deleted.');
    }

    private function cleanDevices(Request $request, array $rules = []): void
    {
        $devices = collect((array) $request->input('devices', []))
            ->map(fn ($d) => trim((string) $d))
            ->filter()
            ->unique()
            ->values()
            ->all();
        $request->merge(['devices' => $devices]);
        if (! empty($devices)) {
            $rules['devices.*'] = 'string|max:255|distinct|unique:devices,intrument_id';
        }
        if (! empty($rules)) {
            $request->validate($rules, ['devices.*.unique' => 'Device :input is already registered.']);
        }
    }
}
