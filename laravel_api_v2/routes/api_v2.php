<?php

/*
|--------------------------------------------------------------------------
| Panel API v2 (JSON) — used by the Flutter web / Android / iOS panel app
|--------------------------------------------------------------------------
| Base URL: https://cloudecg.drcardio.in/api/v2
| Auth:     Authorization: Bearer <token from POST /auth/login> (Sanctum)
| Roles:    the same groups as routes/web.php (admin always passes).
|
| The existing mobile endpoints in routes/api.php are untouched.
*/

use App\Http\Controllers\API\V2\AuthController;
use App\Http\Controllers\API\V2\CardiologistController;
use App\Http\Controllers\API\V2\ClientController;
use App\Http\Controllers\API\V2\DashboardController;
use App\Http\Controllers\API\V2\DeviceController;
use App\Http\Controllers\API\V2\EcgRecordController;
use App\Http\Controllers\API\V2\ExportController;
use App\Http\Controllers\API\V2\LookupController;
use App\Http\Controllers\API\V2\NotificationController;
use App\Http\Controllers\API\V2\OemUserController;
use App\Http\Controllers\API\V2\ProfileController;
use App\Http\Controllers\API\V2\StaffController;
use Illuminate\Support\Facades\Route;

Route::prefix('v2')->middleware('forceJson')->group(function () {

    // ---- Public ------------------------------------------------------------
    // Login has its own per-email limiter (AuthController::login). Route throttles
    // share one counter per IP, so they are only used on the reset-link route.
    Route::post('auth/login', [AuthController::class, 'login']);
    Route::post('auth/forgot-password', [AuthController::class, 'forgotPassword'])->middleware('throttle:6,1');

    Route::middleware('auth:sanctum')->group(function () {

        // ---- Every panel role -------------------------------------------------
        Route::middleware('apiRole:admin,sub_admin,client,cardiologist')->group(function () {
            Route::get('auth/me', [AuthController::class, 'me']);
            Route::post('auth/logout', [AuthController::class, 'logout']);

            Route::get('dashboard', [DashboardController::class, 'index']);

            Route::get('profile', [ProfileController::class, 'show']);
            Route::post('profile', [ProfileController::class, 'update']);

            Route::get('notifications', [NotificationController::class, 'index']);
            Route::post('notifications/read-all', [NotificationController::class, 'readAll']);
            Route::post('notifications/{id}/read', [NotificationController::class, 'read'])->whereNumber('id');

            Route::get('ecg-records', [EcgRecordController::class, 'index']);
            Route::get('ecg-records/summary', [EcgRecordController::class, 'summary']);
            Route::get('ecg-records/{id}', [EcgRecordController::class, 'show'])->whereNumber('id');

            Route::get('lookups/hospitals', [LookupController::class, 'hospitals']);
            Route::get('lookups/cardiologists', [LookupController::class, 'cardiologists']);
            Route::get('lookups/staffs', [LookupController::class, 'staffs']);
            Route::get('lookups/devices', [LookupController::class, 'devices']);
        });

        // ---- Super Admin + OEM users ------------------------------------------
        Route::middleware('apiRole:admin,sub_admin')->group(function () {
            Route::get('clients', [ClientController::class, 'index']);
            Route::post('clients', [ClientController::class, 'store']);
            Route::get('clients/{user}', [ClientController::class, 'show']);
            Route::put('clients/{user}', [ClientController::class, 'update']);
            Route::delete('clients/{user}', [ClientController::class, 'destroy']);
            Route::get('clients/{user}/staff', [StaffController::class, 'forClient']);

            Route::get('devices', [DeviceController::class, 'index']);
            Route::post('devices', [DeviceController::class, 'store']);
            Route::get('devices/{device}', [DeviceController::class, 'show']);
            Route::put('devices/{device}', [DeviceController::class, 'update']);
            Route::delete('devices/{device}', [DeviceController::class, 'destroy']);

            Route::delete('ecg-records/{id}', [EcgRecordController::class, 'destroy'])->whereNumber('id');
            Route::post('ecg-records/{id}/reassign', [EcgRecordController::class, 'reassign'])->whereNumber('id');
            Route::post('ecg-records/{id}/assign', [EcgRecordController::class, 'assign'])->whereNumber('id');
        });

        // ---- Super Admin only -------------------------------------------------
        Route::middleware('apiRole:admin')->group(function () {
            Route::get('oem-users', [OemUserController::class, 'index']);
            Route::post('oem-users', [OemUserController::class, 'store']);
            Route::get('oem-users/{user}', [OemUserController::class, 'show']);
            Route::put('oem-users/{user}', [OemUserController::class, 'update']);
            Route::delete('oem-users/{user}', [OemUserController::class, 'destroy']);

            Route::get('admin-staffs', [StaffController::class, 'adminIndex']);
        });

        // ---- Admin, OEM, Client -----------------------------------------------
        Route::middleware('apiRole:admin,sub_admin,client')->group(function () {
            Route::get('cardiologists', [CardiologistController::class, 'index']);
            Route::post('cardiologists', [CardiologistController::class, 'store']);
            Route::get('cardiologists/{user}', [CardiologistController::class, 'show']);
            Route::put('cardiologists/{user}', [CardiologistController::class, 'update']);
            Route::delete('cardiologists/{user}', [CardiologistController::class, 'destroy']);

            Route::get('exports/ecg/count', [ExportController::class, 'count']);
            Route::post('exports/ecg', [ExportController::class, 'ecg']);

            Route::post('staff', [StaffController::class, 'store']);
            Route::get('staff/{user}', [StaffController::class, 'show']);
            Route::put('staff/{user}', [StaffController::class, 'update']);
            Route::delete('staff/{user}', [StaffController::class, 'destroy']);
        });

        // ---- Client -------------------------------------------------------------
        Route::middleware('apiRole:client')->group(function () {
            Route::get('staffs', [StaffController::class, 'mine']);
        });

        // ---- Cardiologist -----------------------------------------------------
        Route::middleware('apiRole:cardiologist')->group(function () {
            Route::get('ecg-records/{id}/diagnose', [EcgRecordController::class, 'diagnoseForm'])->whereNumber('id');
            Route::post('ecg-records/{id}/diagnose', [EcgRecordController::class, 'diagnose'])->whereNumber('id');
            Route::post('exports/ecg-counts', [ExportController::class, 'ecgCounts']);
            Route::delete('profile/logo', [ProfileController::class, 'deleteLogo']);
            Route::delete('profile/signature', [ProfileController::class, 'deleteSignature']);
        });
    });
});
