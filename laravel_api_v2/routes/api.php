<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\API\StaffController;
use App\Http\Controllers\API\ClientController;
use App\Http\Controllers\API\CardiologistController;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Here is where you can register API routes for your application. These
| routes are loaded by the RouteServiceProvider within a group which
| is assigned the "api" middleware group. Enjoy building your API!
|
*/

/*Route::middleware('auth:api')->get('/user', function (Request $request) {
    return $request->user();
});
*/

Route::namespace('API')->group(function () {
     
    Route::post('login', [StaffController::class, 'login']);
    Route::post('client-login', [ClientController::class, 'login']);
    Route::post('cardio-login', [CardiologistController::class, 'login']);
    Route::get('cardio-get-token', [CardiologistController::class, 'getToken']);
    Route::get('get-token', [StaffController::class, 'getToken']);
    Route::middleware('apitoken')->group(function () {
        
        Route::post('upload-pdf', [StaffController::class, 'uploadClientDevicePdf']);
        Route::get('ecg-list', [StaffController::class, 'ecgRecords']);
        Route::get('client-ecg-list', [ClientController::class, 'ecgRecords']);
        Route::get('auth-device', [StaffController::class, 'authDevice']);
        Route::post('assign-cardiologist', [StaffController::class, 'assignCardiologist']);

        Route::post('cardio-ecg-list', [CardiologistController::class, 'ecgRecords']);
        Route::post('cardio-diagnose', [CardiologistController::class, 'diagnose']);
        Route::get('cardio-get-hospital', [CardiologistController::class, 'getHospital']);
        
        Route::get('cardio-get-profile', [CardiologistController::class, 'getProfile']);
        Route::post('cardio-update-profile', [CardiologistController::class, 'updateProfile']);
        Route::delete('/delete-cardio-logo', [CardiologistController::class, 'deleteCardiologistLogo']);
        Route::delete('/delete-cardio-signature', [CardiologistController::class, 'deleteCardiologistSignature']);
    });          
});

// Panel API v2 (Flutter web / Android / iOS panel app)
require __DIR__.'/api_v2.php';
