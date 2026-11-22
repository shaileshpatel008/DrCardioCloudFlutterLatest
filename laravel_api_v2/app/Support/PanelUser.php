<?php

namespace App\Support;

use App\Models\Cardiologist;
use App\Models\Client;
use App\Models\User;

/**
 * Builds the "who am I and what can I open" payload the Flutter app uses to
 * render role-based navigation. The menu rules mirror config/adminlte.php
 * (the `role` key of every menu item) and the page-level guards in the web
 * controllers (e.g. a client only sees Cardiologists with multi-hospital
 * access, see CardiologistController::check_multi_hospital_access()).
 */
class PanelUser
{
    public const PANEL_ROLES = ['admin', 'sub_admin', 'client', 'cardiologist'];

    public static function primaryRole(User $user): ?string
    {
        foreach (self::PANEL_ROLES as $role) {
            if ($user->hasAnyRole($role)) {
                return $role;
            }
        }

        return null;
    }

    public static function menu(User $user, ?string $role, ?Client $client): array
    {
        $multiHospital = $client && (int) $client->multi_hospital_access === 1;

        $items = ['dashboard'];
        switch ($role) {
            case 'admin':
                array_push($items, 'oem_users', 'clients', 'admin_staffs', 'cardiologists', 'devices', 'ecg_records', 'download_ecg');
                break;
            case 'sub_admin':
                array_push($items, 'clients', 'cardiologists', 'devices', 'ecg_records', 'download_ecg');
                break;
            case 'client':
                if ($multiHospital) {
                    $items[] = 'cardiologists';
                }
                array_push($items, 'client_staffs', 'ecg_records', 'download_ecg');
                break;
            case 'cardiologist':
                array_push($items, 'ecg_records', 'export_ecg_counts', 'notifications');
                break;
        }
        $items[] = 'profile';

        return $items;
    }

    public static function payload(User $user): array
    {
        $role = self::primaryRole($user);
        $client = Client::where('user_id', $user->id)->first();
        $cardiologist = Cardiologist::where('user_id', $user->id)->first();

        $logoUrl = null;
        if ($role === 'sub_admin' && ! empty($user->logo)) {
            $logoUrl = url('/storage/sub_admin/'.$user->id.'/logo/'.$user->logo);
        }

        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'phone_number' => $user->phone_number,
            'role' => $role,
            'role_label' => self::roleLabel($role),
            'oem_access' => (int) ($user->oem_access ?? 0) === 1,
            'logo_url' => $logoUrl,
            'theme_color' => $user->theme_color ?? null,
            'menu' => self::menu($user, $role, $client),
            'client' => $client && $role === 'client' ? [
                'id' => $client->id,
                'hospital_name' => $client->hospital_name,
                'doctor_name' => $client->doctor_name,
                'address' => $client->address,
                'multi_hospital_access' => (int) $client->multi_hospital_access === 1,
                'report_limit_enabled' => (int) $client->report_limit_enabled === 1,
                'report_limit' => (int) $client->report_limit,
            ] : null,
            'cardiologist' => $cardiologist && $role === 'cardiologist' ? [
                'address' => $cardiologist->address,
                'footer' => $cardiologist->footer,
                'logo_url' => ! empty($cardiologist->logo)
                    ? url('/storage/cardiologist/'.$user->id.'/logo/'.$cardiologist->logo) : null,
                'signature_url' => ! empty($cardiologist->signature)
                    ? url('/storage/cardiologist/'.$user->id.'/signature/'.$cardiologist->signature) : null,
            ] : null,
        ];
    }

    public static function roleLabel(?string $role): string
    {
        return match ($role) {
            'admin' => 'Super Admin',
            'sub_admin' => 'OEM User',
            'client' => 'Client',
            'cardiologist' => 'Cardiologist',
            default => 'User',
        };
    }
}
