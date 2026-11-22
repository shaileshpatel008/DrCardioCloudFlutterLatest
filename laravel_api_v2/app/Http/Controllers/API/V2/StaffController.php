<?php

namespace App\Http\Controllers\API\V2;

use App\Http\Controllers\StaffController as WebStaffController;
use App\Models\Client;
use App\Models\ClientStaff;
use App\Models\User;
use Illuminate\Http\Request;

/**
 * Staff (technicians who record ECGs with the mobile app).
 *  - admin: GET /admin-staffs (every staff member, like /admin_staffs)
 *  - admin / OEM: GET /clients/{user}/staff (the "Staff Info" table on a client page)
 *  - client: GET /staffs (their own staff, like /staffs)
 * Create / update / delete reuse the web StaffController actions.
 */
class StaffController extends ApiController
{
    /** GET /api/v2/admin-staffs?page&per_page&search&sort=name|email|client|date&dir — admin only */
    public function adminIndex(Request $request)
    {
        $query = $this->staffQuery()
            ->leftJoin('clients', 'client_staff.client_id', '=', 'clients.id')
            ->addSelect('clients.hospital_name as client_name', 'clients.user_id as client_user_id');

        return $this->paginateStaff($query, $request);
    }

    /** GET /api/v2/clients/{user}/staff — staff of one client (admin / OEM). */
    public function forClient(Request $request, User $user)
    {
        $client = Client::where('user_id', $user->id)->first();
        if (! $client || ! $this->ownsClient($client)) {
            return $this->fail('Client not found.', 404);
        }

        $query = $this->staffQuery()->where('client_staff.client_id', $client->id);

        return $this->paginateStaff($query, $request);
    }

    /** GET /api/v2/staffs — the signed-in client's own staff. */
    public function mine(Request $request)
    {
        $client = Client::where('user_id', $this->user()->id)->first();
        if (! $client) {
            return $this->forbidden();
        }

        $query = $this->staffQuery()
            ->leftJoin('users as cu', 'cu.id', '=', 'client_staff.cardiologist_id')
            ->addSelect('client_staff.cardiologist_id', 'cu.name as cardiologist_name')
            ->where('client_staff.client_id', $client->id);

        return $this->paginateStaff($query, $request);
    }

    /** GET /api/v2/staff/{user} — one staff member for the edit dialog (no password). */
    public function show(User $user)
    {
        $link = ClientStaff::where('staff_id', $user->id)->first();
        if (! $link || ! $this->canManage($link)) {
            return $this->fail('Staff member not found.', 404);
        }

        return $this->ok([
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'phone_number' => $user->phone_number,
            'client_id' => $link->client_id,
            'cardiologist_id' => $link->cardiologist_id,
        ]);
    }

    /**
     * POST /api/v2/staff {client_id (clients.id; admin/OEM only), name, email,
     *   password, password_confirmation, phone_number, cardiologist_id (client only)}
     */
    public function store(Request $request)
    {
        $user = $this->user();
        if ($user->hasAnyRoles(['admin', 'sub_admin'])) {
            $request->validate(['client_id' => 'required|integer']);
            $client = Client::find($request->input('client_id'));
            if (! $client || ! $this->ownsClient($client)) {
                return $this->fail('Please choose a valid client.', 422, ['client_id' => ['Please choose a valid client.']]);
            }
        }

        return $this->fromWeb(app(WebStaffController::class)->store($request), 'Staff member added.');
    }

    /** POST|PUT /api/v2/staff/{user} — password optional. */
    public function update(Request $request, User $user)
    {
        $link = ClientStaff::where('staff_id', $user->id)->first();
        if (! $link || ! $this->canManage($link)) {
            return $this->fail('Staff member not found.', 404);
        }
        if ($request->filled('password')) {
            $request->validate(['password' => 'min:6|confirmed']);
        }

        return $this->fromWeb(app(WebStaffController::class)->update($user, $request), 'Staff member updated.');
    }

    /** DELETE /api/v2/staff/{user} */
    public function destroy(User $user)
    {
        $link = ClientStaff::where('staff_id', $user->id)->first();
        if (! $link || ! $this->canManage($link)) {
            return $this->fail('Staff member not found.', 404);
        }

        return $this->fromWeb(app(WebStaffController::class)->delete($user), 'Staff member deleted.');
    }

    // ---------------------------------------------------------------------

    private function staffQuery()
    {
        return User::select('users.id', 'users.name', 'users.email', 'users.phone_number', 'users.updated_at', 'client_staff.client_id')
            ->join('client_staff', 'client_staff.staff_id', '=', 'users.id')
            ->join('role_user', 'role_user.user_id', '=', 'users.id')
            ->join('roles', 'role_user.role_id', '=', 'roles.id')
            ->where('roles.name', '=', 'staff');
    }

    private function paginateStaff($query, Request $request)
    {
        if ($search = $this->searchTerm($request)) {
            $query->where(function ($q) use ($search) {
                $q->orWhere('users.name', 'like', "%{$search}%")
                    ->orWhere('users.email', 'like', "%{$search}%")
                    ->orWhere('users.phone_number', 'like', "%{$search}%");
            });
        }

        return $this->paginate($query, $request, [
            'name' => 'users.name',
            'email' => 'users.email',
            'date' => 'users.updated_at',
        ], 'date', fn ($r) => [
            'id' => $r->id,
            'name' => $r->name,
            'email' => $r->email,
            'phone_number' => $r->phone_number,
            'client_id' => $r->client_id,
            'client_name' => $r->client_name ?? null,
            'client_user_id' => $r->client_user_id ?? null,
            'cardiologist_id' => $r->cardiologist_id ?? null,
            'cardiologist_name' => $r->cardiologist_name ?? null,
            'updated_at' => $this->iso($r->updated_at),
            'updated_at_display' => $this->display($r->updated_at),
        ]);
    }

    private function canManage(ClientStaff $link): bool
    {
        $user = $this->user();
        $client = Client::find($link->client_id);
        if ($user->hasAnyRoles(['admin', 'sub_admin'])) {
            return $this->ownsClient($client);
        }

        return $client && (int) $client->user_id === (int) $user->id;
    }
}
