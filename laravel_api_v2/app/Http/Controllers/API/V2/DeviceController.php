<?php

namespace App\Http\Controllers\API\V2;

use App\Http\Controllers\DeviceController as WebDeviceController;
use App\Models\Client;
use App\Models\Device;
use Illuminate\Http\Request;

class DeviceController extends ApiController
{
    /** GET /api/v2/devices?page&per_page&search&hospital_id&sort=hospital|device|date&dir */
    public function index(Request $request)
    {
        $query = Device::select('devices.id', 'devices.intrument_id', 'devices.client_id', 'devices.updated_at', 'clients.hospital_name', 'clients.user_id as client_user_id')
            ->leftJoin('clients', 'clients.id', '=', 'devices.client_id');

        $this->scopeByParent($query, 'clients.parent_user_id');

        if ($hospitalId = $request->input('hospital_id')) {
            $query->where('clients.id', '=', $hospitalId);
        }
        if ($search = $this->searchTerm($request)) {
            $query->where(function ($q) use ($search) {
                $q->orWhere('clients.hospital_name', 'like', "%{$search}%")
                    ->orWhere('devices.intrument_id', 'like', "%{$search}%");
            });
        }

        return $this->paginate($query, $request, [
            'hospital' => 'clients.hospital_name',
            'device' => 'devices.intrument_id',
            'date' => 'devices.updated_at',
        ], 'device', fn ($d) => $this->present($d));
    }

    /** GET /api/v2/devices/{device} */
    public function show(Device $device)
    {
        if (! $this->canManage($device)) {
            return $this->fail('Device not found.', 404);
        }
        $client = Client::find($device->client_id);
        $device->hospital_name = $client?->hospital_name;
        $device->client_user_id = $client?->user_id;

        return $this->ok($this->present($device));
    }

    /** POST /api/v2/devices {hospital_id (clients.id), intrument_id} */
    public function store(Request $request)
    {
        $request->validate(['hospital_id' => 'required|integer']);
        if (! $this->ownsClient(Client::find($request->input('hospital_id')))) {
            return $this->fail('Please choose a valid hospital.', 422, ['hospital_id' => ['Please choose a valid hospital.']]);
        }
        $request->merge(['hospital_name' => $request->input('hospital_id')]);

        return $this->fromWeb(app(WebDeviceController::class)->store($request), 'Device saved successfully.');
    }

    /** POST|PUT /api/v2/devices/{device} {hospital_id, intrument_id} */
    public function update(Request $request, Device $device)
    {
        if (! $this->canManage($device)) {
            return $this->fail('Device not found.', 404);
        }
        $request->validate(['hospital_id' => 'required|integer']);
        if (! $this->ownsClient(Client::find($request->input('hospital_id')))) {
            return $this->fail('Please choose a valid hospital.', 422, ['hospital_id' => ['Please choose a valid hospital.']]);
        }
        $request->merge(['hospital_name' => $request->input('hospital_id')]);

        return $this->fromWeb(app(WebDeviceController::class)->update($device, $request), 'Device updated successfully.');
    }

    /** DELETE /api/v2/devices/{device} — renames to "-REASSIGNED" then soft-deletes, like the web. */
    public function destroy(Device $device)
    {
        if (! $this->canManage($device)) {
            return $this->fail('Device not found.', 404);
        }

        return $this->fromWeb(app(WebDeviceController::class)->delete($device), 'Device deleted.');
    }

    private function canManage(Device $device): bool
    {
        $client = Client::find($device->client_id);
        if ($this->isOemScoped()) {
            return $client && (int) $client->parent_user_id === (int) $this->user()->id;
        }

        return true;
    }

    private function present($d): array
    {
        return [
            'id' => $d->id,
            'instrument_id' => $d->intrument_id,
            'hospital_id' => $d->client_id,
            'hospital_name' => $d->hospital_name,
            'client_user_id' => $d->client_user_id,
            'updated_at' => $this->iso($d->updated_at),
            'updated_at_display' => $this->display($d->updated_at),
        ];
    }
}
