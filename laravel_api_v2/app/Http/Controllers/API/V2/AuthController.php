<?php

namespace App\Http\Controllers\API\V2;

use App\Models\User;
use App\Support\PanelUser;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;

class AuthController extends ApiController
{
    /**
     * POST /api/v2/auth/login  {email, password, device_name?}
     *
     * Same rules as the web login (AuthenticatedSessionController::store):
     * only admin / sub_admin / client / cardiologist accounts may sign in to
     * the panel, and passwords are checked against the encrypted value the
     * panel stores (Crypt::encryptString).
     */
    public function login(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
            'password' => 'required|string',
        ]);

        $throttleKey = Str::lower($request->input('email')).'|'.$request->ip();
        if (RateLimiter::tooManyAttempts($throttleKey, 5)) {
            $seconds = RateLimiter::availableIn($throttleKey);

            return $this->fail("Too many login attempts. Please try again in {$seconds} seconds.", 429);
        }

        $user = User::where('email', $request->input('email'))->first();

        $passwordOk = false;
        if ($user) {
            try {
                $passwordOk = hash_equals(Crypt::decryptString($user->password), (string) $request->input('password'));
            } catch (\Throwable $e) {
                $passwordOk = false;
            }
        }

        if (! $user || ! $passwordOk) {
            RateLimiter::hit($throttleKey);

            return $this->fail('The credentials do not match.', 422, ['email' => ['The credentials do not match.']]);
        }

        if (! PanelUser::primaryRole($user)) {
            return $this->fail('This account cannot sign in to the panel. Please use the Dr. Cardio mobile app.', 403);
        }

        RateLimiter::clear($throttleKey);

        $deviceName = Str::limit((string) $request->input('device_name', 'panel'), 100, '');
        $token = $user->createToken('panel:'.$deviceName)->plainTextToken;

        return $this->ok([
            'token' => $token,
            'token_type' => 'Bearer',
            'user' => PanelUser::payload($user),
        ], 'Signed in successfully.');
    }

    /** GET /api/v2/auth/me */
    public function me(Request $request)
    {
        return $this->ok(PanelUser::payload($request->user()));
    }

    /** POST /api/v2/auth/logout — revokes only the token used for this call. */
    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()?->delete();

        return $this->ok(null, 'Signed out.');
    }

    /** POST /api/v2/auth/forgot-password {email} — same mail as the web flow. */
    public function forgotPassword(Request $request)
    {
        $request->validate(['email' => 'required|email']);

        $status = Password::sendResetLink($request->only('email'));

        if ($status === Password::RESET_LINK_SENT) {
            return $this->ok(null, __($status));
        }

        return $this->fail(__($status), 422, ['email' => [__($status)]]);
    }
}
