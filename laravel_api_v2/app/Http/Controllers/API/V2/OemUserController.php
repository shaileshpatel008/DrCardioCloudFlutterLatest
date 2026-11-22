<?php

namespace App\Http\Controllers\API\V2;

use App\Http\Controllers\OemController as WebOemController;
use App\Models\Cardiologist;
use App\Models\Client;
use App\Models\User;
use Illuminate\Http\Request;

/** OEM users (role sub_admin) — Super Admin only. */
class OemUserController extends ApiController
{
    /** GET /api/v2/oem-users?page&per_page&search&sort=name|email|date&dir */
    public function index(Request $request)
    {
        $query = $this->baseQuery();

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
        ], 'date', fn ($u) => [
            'id' => $u->id,
            'name' => $u->name,
            'email' => $u->email,
            'phone_number' => $u->phone_number,
            'clients_count' => Client::where('parent_user_id', $u->id)->count(),
            'updated_at' => $this->iso($u->updated_at),
            'updated_at_display' => $this->display($u->updated_at),
        ]);
    }

    /** GET /api/v2/oem-users/{user} (no password) */
    public function show(User $user)
    {
        if (! $user->hasAnyRole('sub_admin')) {
            return $this->fail('OEM user not found.', 404);
        }

        return $this->ok([
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'phone_number' => $user->phone_number,
            'created_at' => $this->iso($user->created_at),
            'updated_at' => $this->iso($user->updated_at),
            'clients_count' => Client::where('parent_user_id', $user->id)->count(),
            'cardiologists_count' => Cardiologist::where('parent_user_id', $user->id)->count(),
        ]);
    }

    /** POST /api/v2/oem-users {name, email, password, password_confirmation, phone_number} */
    public function store(Request $request)
    {
        return $this->fromWeb(app(WebOemController::class)->store($request), 'OEM user saved successfully.');
    }

    /** POST|PUT /api/v2/oem-users/{user} — password optional. */
    public function update(Request $request, User $user)
    {
        if (! $user->hasAnyRole('sub_admin')) {
            return $this->fail('OEM user not found.', 404);
        }
        if ($request->filled('password')) {
            $request->validate(['password' => 'min:6|confirmed']);
        }

        return $this->fromWeb(app(WebOemController::class)->update($user, $request), 'OEM user updated successfully.');
    }

    /**
     * DELETE /api/v2/oem-users/{user}
     * Note: the web list's Delete button posts to /client/{id}/delete by
     * mistake (it fails for OEM users). The API calls OemController::delete,
     * which is the action that was intended.
     */
    public function destroy(User $user)
    {
        if (! $user->hasAnyRole('sub_admin')) {
            return $this->fail('OEM user not found.', 404);
        }

        return $this->fromWeb(app(WebOemController::class)->delete($user), 'OEM user deleted.');
    }

    private function baseQuery()
    {
        return User::select('users.id', 'users.name', 'users.email', 'users.phone_number', 'users.updated_at')
            ->join('role_user', 'role_user.user_id', '=', 'users.id')
            ->join('roles', 'role_user.role_id', '=', 'roles.id')
            ->where('roles.name', '=', 'sub_admin');
    }
}
