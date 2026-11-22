<?php

namespace App\Http\Controllers\API\V2;

use App\Http\Controllers\CardiologistController as WebCardiologistController;
use App\Models\Cardiologist;
use App\Models\Client;
use App\Models\ClientCardiologist;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Cardiologists — admin, OEM users, and clients that have multi-hospital
 * access (the same gate as CardiologistController::check_multi_hospital_access).
 */
class CardiologistController extends ApiController
{
    /** GET /api/v2/cardiologists?page&per_page&search&sort=name|email|date&dir */
    public function index(Request $request)
    {
        if ($blocked = $this->clientGate()) {
            return $blocked;
        }

        $user = $this->user();
        $query = User::select('users.id', 'users.name', 'users.email', 'users.phone_number', 'users.updated_at', 'cardiologist.address',
            DB::raw('(SELECT COUNT(*) FROM client_cardiologist ccx JOIN users cux ON cux.id = ccx.client_id AND cux.deleted_at IS NULL WHERE ccx.cardiologist_id = users.id) AS clients_count'))
            ->join('cardiologist', 'cardiologist.user_id', '=', 'users.id')
            ->join('role_user', 'role_user.user_id', '=', 'users.id')
            ->join('roles', 'role_user.role_id', '=', 'roles.id')
            ->where('roles.name', '=', 'cardiologist')
            ->whereNull('cardiologist.deleted_at');

        if ($this->isOemScoped()) {
            $query->where('cardiologist.parent_user_id', $user->id);
        } elseif ($this->isAdmin()) {
            $query->where('cardiologist.parent_user_id', 0);
        } elseif ($user->hasAnyRole('client')) {
            $query->whereExists(function ($q) use ($user) {
                $q->select(DB::raw(1))->from('client_cardiologist')
                    ->whereColumn('client_cardiologist.cardiologist_id', 'cardiologist.user_id')
                    ->where('client_cardiologist.client_id', $user->id);
            });
        }

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
            'address' => $r->address,
            'clients_count' => (int) $r->clients_count,
            'updated_at' => $this->iso($r->updated_at),
            'updated_at_display' => $this->display($r->updated_at),
        ]);
    }

    /** GET /api/v2/cardiologists/{user} (no password) */
    public function show(User $user)
    {
        if ($blocked = $this->clientGate()) {
            return $blocked;
        }
        $cardiologist = Cardiologist::where('user_id', $user->id)->first();
        if (! $cardiologist || ! $this->ownsCardiologist($cardiologist)) {
            return $this->fail('Cardiologist not found.', 404);
        }

        $clients = Client::select('clients.id', 'clients.user_id', 'clients.hospital_name')
            ->join('client_cardiologist', 'client_cardiologist.client_id', '=', 'clients.user_id')
            ->where('client_cardiologist.cardiologist_id', $user->id)
            ->get();

        return $this->ok([
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'phone_number' => $user->phone_number,
            'address' => $cardiologist->address,
            'created_at' => $this->iso($user->created_at),
            'updated_at' => $this->iso($user->updated_at),
            'clients' => $clients->map(fn ($c) => ['id' => $c->user_id, 'hospital_name' => $c->hospital_name])->values(),
        ]);
    }

    /** POST /api/v2/cardiologists {name, email, password, password_confirmation, address, phone_number} */
    public function store(Request $request)
    {
        if ($blocked = $this->clientGate()) {
            return $blocked;
        }

        return $this->fromWeb(app(WebCardiologistController::class)->store($request), 'Cardiologist saved successfully.');
    }

    /** POST|PUT /api/v2/cardiologists/{user} — password optional. */
    public function update(Request $request, User $user)
    {
        if ($blocked = $this->clientGate()) {
            return $blocked;
        }
        $cardiologist = Cardiologist::where('user_id', $user->id)->first();
        if (! $cardiologist || ! $this->ownsCardiologist($cardiologist)) {
            return $this->fail('Cardiologist not found.', 404);
        }
        if ($request->filled('password')) {
            $request->validate(['password' => 'min:6|confirmed']);
        }

        return $this->fromWeb(app(WebCardiologistController::class)->update($user, $request), 'Cardiologist updated successfully.');
    }

    /** DELETE /api/v2/cardiologists/{user} */
    public function destroy(User $user)
    {
        if ($blocked = $this->clientGate()) {
            return $blocked;
        }
        $cardiologist = Cardiologist::where('user_id', $user->id)->first();
        if (! $cardiologist || ! $this->ownsCardiologist($cardiologist)) {
            return $this->fail('Cardiologist not found.', 404);
        }

        return $this->fromWeb(app(WebCardiologistController::class)->delete($user), 'Cardiologist deleted.');
    }

    /** Clients without multi-hospital access cannot open this section (web redirects them). */
    private function clientGate()
    {
        $user = $this->user();
        if ($user->hasAnyRole('client') && ! $user->hasAnyRoles(['admin', 'sub_admin'])) {
            $client = Client::where('user_id', $user->id)->first();
            if (! $client || (int) $client->multi_hospital_access !== 1) {
                return $this->forbidden('Cardiologists are available to clients with multi-hospital access.');
            }
        }

        return null;
    }
}
