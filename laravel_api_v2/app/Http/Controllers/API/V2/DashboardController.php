<?php

namespace App\Http\Controllers\API\V2;

use App\Http\Controllers\API\V2\Concerns\BuildsEcgQueries;
use App\Http\Controllers\HomeController;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;

class DashboardController extends ApiController
{
    use BuildsEcgQueries;

    /**
     * GET /api/v2/dashboard
     *
     * `counts` comes straight from HomeController::index() (the Blade
     * dashboard), so every tile shows exactly the number the web panel shows
     * for the same user. `insights` and `recent` are the new dashboard
     * panels; they use the same role scope as the ECG Records list.
     */
    public function index()
    {
        $view = app(HomeController::class)->index();
        $d = $view->getData();

        $counts = [
            'clients' => (int) ($d['totalClientCount'] ?? 0),
            'devices' => (int) ($d['totalDeviceCount'] ?? 0),
            'ecg_records' => (int) ($d['totalEcgRecordCount'] ?? 0),
            'cardiologists' => (int) ($d['totalCardiologistCount'] ?? 0),
            'staffs' => (int) ($d['totalStaffsCount'] ?? 0),
            'normal_ecg' => (int) ($d['totalNormalEcgRecordCount'] ?? 0),
            'abnormal_ecg' => (int) ($d['totalAbnormalEcgRecordCount'] ?? 0),
        ];

        // Which tiles the Blade dashboard (home.blade.php) shows for this role.
        $user = $this->user();
        if ($user->hasAnyRoles(['admin', 'sub_admin'])) {
            $tiles = ['ecg_records', 'clients', 'devices', 'cardiologists', 'staffs'];
        } elseif ($user->hasAnyRole('cardiologist')) {
            $tiles = ['ecg_records', 'normal_ecg', 'abnormal_ecg'];
        } else {
            $tiles = ['ecg_records', 'staffs'];
        }

        return $this->ok([
            'tiles' => $tiles,
            'counts' => $counts,
            'insights' => $this->insights(),
            'recent' => $this->ecgBaseQuery()
                ->orderBy('pdfs.updated_at', 'desc')
                ->limit(6)
                ->get()
                ->map(fn ($row) => $this->presentEcg($row))
                ->values(),
        ]);
    }

    private function insights(): array
    {
        $tz = config('app.timezone');
        $from = Carbon::now($tz)->subDays(13)->startOfDay();
        $monthStart = Carbon::now($tz)->startOfMonth();

        $daily = (clone $this->ecgBaseQuery())->reorder()
            ->select(DB::raw('DATE(pdfs.updated_at) as day'), DB::raw('COUNT(*) as total'))
            ->where('pdfs.updated_at', '>=', $from)
            ->groupBy(DB::raw('DATE(pdfs.updated_at)'))
            ->pluck('total', 'day');

        $days = [];
        for ($i = 0; $i < 14; $i++) {
            $day = $from->copy()->addDays($i)->toDateString();
            $days[] = ['date' => $day, 'total' => (int) ($daily[$day] ?? 0)];
        }

        $statusMix = (clone $this->ecgBaseQuery())->reorder()
            ->select(DB::raw('pdfs.status as status'), DB::raw('COUNT(*) as total'))
            ->where('pdfs.updated_at', '>=', $monthStart)
            ->groupBy('pdfs.status')
            ->pluck('total', 'status');

        $ecgMix = (clone $this->ecgBaseQuery())->reorder()
            ->select(DB::raw('pdfs.ecg_status as ecg_status'), DB::raw('COUNT(*) as total'))
            ->where('pdfs.updated_at', '>=', $monthStart)
            ->whereIn('pdfs.ecg_status', ['normal', 'abnormal'])
            ->groupBy('pdfs.ecg_status')
            ->pluck('total', 'ecg_status');

        $avgTat = (clone $this->ecgBaseQuery())->reorder()
            ->select(DB::raw('AVG(TIMESTAMPDIFF(MINUTE, pdfs.requested_time, pdfs.reported_time)) as avg_tat'))
            ->where('pdfs.status', 'reported')
            ->whereNotNull('pdfs.requested_time')
            ->whereNotNull('pdfs.reported_time')
            ->where('pdfs.updated_at', '>=', $monthStart)
            ->first()?->avg_tat;

        return [
            'daily' => $days,
            'month_status' => [
                'pending' => (int) ($statusMix['pending'] ?? 0),
                'requested' => (int) ($statusMix['requested'] ?? 0),
                'reported' => (int) ($statusMix['reported'] ?? 0),
                'no_credit' => (int) ($statusMix['no_credit'] ?? 0),
            ],
            'month_ecg_status' => [
                'normal' => (int) ($ecgMix['normal'] ?? 0),
                'abnormal' => (int) ($ecgMix['abnormal'] ?? 0),
            ],
            'avg_tat_minutes' => is_null($avgTat) ? null : (int) round($avgTat),
        ];
    }
}
