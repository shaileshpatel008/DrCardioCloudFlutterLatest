<?php

namespace App\Http\Controllers\API\V2;

use App\Http\Controllers\UserController as WebUserController;
use App\Models\Client;
use App\Models\Cardiologist;
use App\Support\PanelUser;
use Illuminate\Http\Request;

/**
 * My Profile — the same fields /edit-profile offers per role:
 *  all:          name, password (+ confirmation)
 *  client:       hospital_name, doctor_name, address
 *  OEM user:     logo, theme_color
 *  cardiologist: address, logo, signature (with stamp), footer — used on reports
 */
class ProfileController extends ApiController
{
    /** GET /api/v2/profile */
    public function show()
    {
        $user = $this->user();
        $payload = PanelUser::payload($user);

        $client = Client::where('user_id', $user->id)->first();
        $cardiologist = Cardiologist::where('user_id', $user->id)->first();

        $payload['editable'] = [
            'hospital_name' => $payload['role'] === 'client' ? $client?->hospital_name : null,
            'doctor_name' => $payload['role'] === 'client' ? $client?->doctor_name : null,
            'address' => $payload['role'] === 'client' ? $client?->address
                : ($payload['role'] === 'cardiologist' ? $cardiologist?->address : null),
            'footer' => $payload['role'] === 'cardiologist' ? $cardiologist?->footer : null,
        ];

        return $this->ok($payload);
    }

    /**
     * POST /api/v2/profile (multipart when uploading logo / signature)
     * {name, password?, password_confirmation?, hospital_name?, doctor_name?,
     *  address?, footer?, theme_color?, logo?, signature?}
     */
    public function update(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'password' => 'nullable|min:6|confirmed',
            'logo' => 'nullable|image|max:30000',
            'signature' => 'nullable|image|max:30000',
        ]);

        $user = $this->user();
        if ($user->hasAnyRole('client') && ! $request->filled('hospital_name')) {
            return $this->fail('Hospital name is required.', 422, ['hospital_name' => ['Hospital name is required.']]);
        }

        app(WebUserController::class)->update($request);

        $payload = $this->show()->getData(true);
        $payload['message'] = 'Profile updated successfully.';

        return response()->json($payload);
    }

    /** DELETE /api/v2/profile/logo — cardiologist report logo */
    public function deleteLogo(Request $request)
    {
        app(WebUserController::class)->deleteCardiologistLogo($request);

        return $this->ok(null, 'Logo removed.');
    }

    /** DELETE /api/v2/profile/signature — cardiologist signature */
    public function deleteSignature(Request $request)
    {
        app(WebUserController::class)->deleteCardiologistSignature($request);

        return $this->ok(null, 'Signature removed.');
    }
}
