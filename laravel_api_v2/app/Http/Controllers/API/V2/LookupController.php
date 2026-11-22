<?php

namespace App\Http\Controllers\API\V2;

use App\Models\Client;
use App\Models\Device;
use App\Models\User;
use Illuminate\Http\Request;

/**
 * Dropdown sources for filters and forms. Each one copies the query the
 * matching web page uses to fill its <select>.
 */
class LookupController extends ApiController
{
    /** GET /api/v2/lookups/hospitals — clients (hospitals) this user can pick. */
    public function hospitals()
    {
        $user = $this->user();
        $query = Client::select('clients.id', 'clients.hospital_name', 'clients.user_id');

        if ($user->hasAnyRoles(['admin', 'sub_admin'])) {
            $this->scopeByParent($query, 'clients.parent_user_id');
        } elseif ($user->hasAnyRole('cardiologist')) {
            // PdfsController::clientPdfList — hospitals linked to this cardiologist.
            $query->join('client_cardiologist', 'client_cardiologist.client_id', '=', 'clients.user_id')
                ->where('client_cardiologist.cardiologist_id', $user->id);
        } else {
            $query->where('clients.user_id', $user->id);
        }

        return $this->ok($query->orderBy('clients.hospital_name')->get()->map(fn ($c) => [
            'id' => $c->id,
            'name' => $c->hospital_name,
            'user_id' => $c->user_id,
        ])->unique('id')->values());
    }

    /**
     * GET /api/v2/lookups/cardiologists — for client forms, the ECG
     * re-assign dialog and filters. Client users get their own linked
     * cardiologists (StaffController::index).
     */
    public function cardiologists()
    {
        $user = $this->user();
        $query = User::select('users.id', 'users.name')
            ->join('role_user', 'role_user.user_id', '=', 'users.id')
            ->join('roles', 'role_user.role_id', '=', 'roles.id')
            ->leftJoin('cardiologist', 'cardiologist.user_id', '=', 'users.id')
            ->where('roles.name', '=', 'cardiologist');

        if ($user->hasAnyRole('client') && ! $user->hasAnyRoles(['admin', 'sub_admin'])) {
            $query->join('client_cardiologist', 'client_cardiologist.cardiologist_id', '=', 'users.id')
                ->where('client_cardiologist.client_id', $user->id);
        } else {
            $this->scopeCardiologistOwner($query);
        }

        return $this->ok($query->orderBy('users.name')->get()->unique('id')->values());
    }

    /** GET /api/v2/lookups/staffs?hospital_id= (StaffController::staffsByHospital) */
    public function staffs(Request $request)
    {
        $hospitalId = (int) $request->input('hospital_id');
        if (! $hospitalId || ! $this->canUseHospital($hospitalId)) {
            return $this->ok([]);
        }

        $rows = User::select('users.id', 'users.name')
            ->join('client_staff', 'client_staff.staff_id', '=', 'users.id')
            ->join('role_user', 'role_user.user_id', '=', 'users.id')
            ->join('roles', 'role_user.role_id', '=', 'roles.id')
            ->where('roles.name', '=', 'staff')
            ->where('client_staff.client_id', '=', $hospitalId)
            ->orderBy('users.name')
            ->get();

        return $this->ok($rows);
    }

    /** GET /api/v2/lookups/devices?hospital_id= (StaffController::devicesByHospital) */
    public function devices(Request $request)
    {
        $hospitalId = (int) $request->input('hospital_id');
        if (! $hospitalId || ! $this->canUseHospital($hospitalId)) {
            return $this->ok([]);
        }

        $rows = Device::select('devices.id', 'devices.intrument_id')
            ->where('devices.client_id', '=', $hospitalId)
            ->orderBy('devices.intrument_id')
            ->get()
            ->map(fn ($d) => ['id' => $d->id, 'name' => $d->intrument_id]);

        return $this->ok($rows);
    }

    /** Is this hospital (clients.id) inside the user's own scope? */
    private function canUseHospital(int $hospitalId): bool
    {
        $user = $this->user();
        $client = Client::find($hospitalId);
        if (! $client) {
            return false;
        }
        if ($user->hasAnyRoles(['admin', 'sub_admin'])) {
            return $this->ownsClient($client);
        }
        if ($user->hasAnyRole('cardiologist')) {
            return \App\Models\ClientCardiologist::where('client_id', $client->user_id)
                ->where('cardiologist_id', $user->id)->exists();
        }

        return (int) $client->user_id === (int) $user->id;
    }
}
