<?php

namespace App\Http\Controllers\API\V2\Concerns;

use App\Http\Controllers\PdfsController;
use App\Models\PdfData;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * One place that knows how ECG records are joined, scoped per role and
 * filtered — taken from PdfsController::filterPdfList (admin / OEM) and
 * PdfsController::filterClientPdfList (client / cardiologist).
 *
 * Difference on purpose: the client's assigned cardiologist is read with a
 * sub-select instead of a LEFT JOIN on client_cardiologist, so a client with
 * more than one row there can never duplicate ECG rows in the list.
 */
trait BuildsEcgQueries
{
    protected function ecgBaseQuery(bool $withReport = false, bool $applyRoleScope = true)
    {
        $columns = [
            'pdfs.id',
            'pdfs.staff_id',
            'pdfs.device_id',
            'devices.intrument_id',
            'pdfs.pdf',
            'pdfs.document_slug',
            'pdfs.original_file_name',
            'pdfs.csv_file_name',
            'pdfs.created_at',
            'pdfs.updated_at',
            'su.name as staff_name',
            'c.id as client_id',
            'c.user_id as client_user_id',
            'c.hospital_name',
            'c.doctor_name',
            'c.multi_hospital_access',
            'pdfs.latitude',
            'pdfs.longitude',
            'pdfs.device_info',
            'pdfs.patient_info',
            'pdfs.address',
            'pdfs.status',
            'pdfs.ecg_status',
            'pdfs.requested_time',
            'pdfs.reported_time',
            'pdfs.cardiologist_id',
            'pdfs.is_reassigned',
            'cu.name as cardiologist_name',
            'pdfs.hr', 'pdfs.r', 'pdfs.rr', 'pdfs.pr', 'pdfs.qrs', 'pdfs.qt', 'pdfs.qtc', 'pdfs.qt_by_qtc',
            DB::raw('(SELECT ccx.cardiologist_id FROM client_cardiologist ccx WHERE ccx.client_id = c.user_id ORDER BY ccx.id LIMIT 1) AS client_cardiologist_id'),
        ];
        if ($withReport) {
            $columns[] = 'pdfs.cardiologist_report';
        }

        $query = PdfData::select($columns)
            ->leftJoin('users as su', 'su.id', '=', 'pdfs.staff_id')
            ->leftJoin('client_staff as cf', 'cf.staff_id', '=', 'pdfs.staff_id')
            ->leftJoin('clients as c', 'c.id', '=', 'cf.client_id')
            ->leftJoin('devices', 'devices.id', '=', 'pdfs.device_id')
            ->leftJoin('users as cu', 'cu.id', '=', 'pdfs.cardiologist_id');

        if ($applyRoleScope) {
            $this->applyEcgRoleScope($query);
        }

        return $query;
    }

    protected function applyEcgRoleScope($query)
    {
        $user = $this->user();

        if ($user->hasAnyRoles(['admin', 'sub_admin'])) {
            $this->scopeByParent($query, 'c.parent_user_id');
        } elseif ($user->hasAnyRole('cardiologist')) {
            $query->where('pdfs.cardiologist_id', '=', $user->id);
        } else {
            $query->where('c.user_id', '=', $user->id);
        }

        return $query;
    }

    /** Filters shared by the list, the status summary and the exports. */
    protected function applyEcgFilters($query, Request $request, bool $includeStatus = true)
    {
        if ($v = $request->input('hospital_id')) {
            $query->where('c.id', '=', $v);
        }
        if ($v = $request->input('staff_id')) {
            $query->where('pdfs.staff_id', '=', $v);
        }
        if ($v = $request->input('device_id')) {
            $query->where('pdfs.device_id', '=', $v);
        }
        if ($v = $request->input('cardiologist_id')) {
            $query->where('pdfs.cardiologist_id', '=', $v);
        }
        if (($v = $request->input('ecg_status')) && in_array($v, ['normal', 'abnormal', 'borderline'], true)) {
            $query->where('pdfs.ecg_status', '=', $v);
        }
        if ($includeStatus && ($v = $request->input('status')) && in_array($v, ['pending', 'requested', 'reported', 'no_credit'], true)) {
            $query->where('pdfs.status', '=', $v);
        }

        $search = trim((string) $request->input('search', ''));
        if ($search !== '') {
            $isAdminSide = $this->user()->hasAnyRoles(['admin', 'sub_admin']);
            $query->where(function ($q) use ($search, $isAdminSide) {
                $q->orWhere('c.hospital_name', 'like', "%{$search}%")
                    ->orWhere('devices.intrument_id', 'like', "%{$search}%")
                    ->orWhere('su.name', 'like', "%{$search}%")
                    ->orWhere('pdfs.original_file_name', 'like', "%{$search}%")
                    ->orWhere('pdfs.address', 'like', "%{$search}%");
                if ($isAdminSide) {
                    $q->orWhere('pdfs.patient_info', 'like', "%{$search}%");
                }
            });
        }

        $dateFilter = $request->input('date_filter');
        if (! empty($dateFilter)) {
            if ($dateFilter === 'custom' && (! $request->filled('from_date') || ! $request->filled('to_date'))) {
                return $query;
            }
            // Reuse the panel's own date presets so "Last week" etc. match exactly.
            app(PdfsController::class)->getDateRange(
                $dateFilter,
                $query,
                $request->input('from_date'),
                $request->input('to_date')
            );
        }

        return $query;
    }

    /** Shape one ECG row for the app. */
    protected function presentEcg($row, bool $detail = false): array
    {
        $user = $this->user();
        $isAdminSide = $user->hasAnyRoles(['admin', 'sub_admin']);
        $isCardiologist = ! $isAdminSide && $user->hasAnyRole('cardiologist');

        $base = 'staff/'.$row->staff_id.'/'.$row->document_slug.'/';
        $ecgUrl = $this->storageUrl($base.$row->pdf);
        $reportUrl = null;
        if ($row->status === 'reported') {
            $reportUrl = $this->storageUrl($base.pathinfo($row->pdf, PATHINFO_FILENAME).'_merged_report.pdf');
        }

        $tat = null;
        if ($row->status === 'reported' && $row->requested_time && $row->reported_time) {
            $tat = (int) round((strtotime($row->reported_time) - strtotime($row->requested_time)) / 60);
        }

        $statusLabel = match ($row->status) {
            'reported' => 'Reported',
            'requested' => 'Requested',
            'no_credit' => 'No credit',
            default => is_null($row->client_cardiologist_id) ? 'NA' : 'Pending',
        };

        $hasClientCardiologist = ! is_null($row->client_cardiologist_id);
        $patient = $this->jsonColumn($row->patient_info);

        $data = [
            'id' => $row->id,
            'file_name' => $row->original_file_name ?: $row->pdf,
            'ecg_pdf_url' => $ecgUrl,
            'report_pdf_url' => $reportUrl,
            'staff_id' => $row->staff_id,
            'staff_name' => $row->staff_name,
            'client_id' => $row->client_id,
            'client_user_id' => $row->client_user_id,
            'hospital_name' => $row->hospital_name,
            'doctor_name' => $row->doctor_name,
            'device_id' => $row->device_id,
            'instrument_id' => $row->intrument_id,
            'cardiologist_id' => $row->cardiologist_id,
            'cardiologist_name' => $row->cardiologist_name,
            'is_reassigned' => (int) $row->is_reassigned === 1,
            'status' => $row->status,
            'status_label' => $statusLabel,
            'ecg_status' => $this->cleanString($row->ecg_status),
            'tat_minutes' => $tat,
            'address' => $this->cleanString($row->address),
            'latitude' => $this->cleanString($row->latitude),
            'longitude' => $this->cleanString($row->longitude),
            'patient' => is_array($patient) ? [
                'name' => $patient['Name'] ?? null,
                'age' => $patient['Age'] ?? null,
                'gender' => $patient['Gender'] ?? null,
                'id' => $patient['Id'] ?? null,
            ] : null,
            'device_info' => $this->jsonColumn($row->device_info),
            'requested_at' => $this->iso($row->requested_time),
            'reported_at' => $this->iso($row->reported_time),
            'created_at' => $this->iso($row->created_at),
            'updated_at' => $this->iso($row->updated_at),
            'updated_at_display' => $this->display($row->updated_at),
            'measurements' => [
                'hr' => $row->hr, 'r' => $row->r, 'rr' => $row->rr, 'pr' => $row->pr,
                'qrs' => $row->qrs, 'qt' => $row->qt, 'qtc' => $row->qtc, 'qt_by_qtc' => $row->qt_by_qtc,
            ],
            'actions' => [
                'view_report' => $reportUrl !== null,
                'delete' => $isAdminSide,
                'reassign' => $isAdminSide && $row->client_id && $row->status === 'requested' && $hasClientCardiologist,
                'assign' => $isAdminSide && $row->client_id && $row->status === 'no_credit' && $hasClientCardiologist,
                'diagnose' => $isCardiologist && $row->status === 'requested',
                'edit_report' => $isCardiologist && $row->status === 'reported',
            ],
        ];

        if ($detail) {
            $data['cardiologist_report'] = $row->cardiologist_report;
            $data['csv_url'] = $row->csv_file_name
                ? $this->storageUrl($base.'csv_files/'.$row->csv_file_name) : null;
            $data['cardiologist_report_pdf_url'] = $row->status === 'reported'
                ? $this->storageUrl($base.pathinfo($row->original_file_name, PATHINFO_FILENAME).'_cardiologist_report.pdf') : null;
        }

        return $data;
    }

    protected function ecgSortMap(): array
    {
        return [
            'date' => 'pdfs.updated_at',
            'staff' => 'su.name',
            'hospital' => 'c.hospital_name',
            'device' => 'devices.intrument_id',
            'status' => 'pdfs.status',
            'file' => 'pdfs.original_file_name',
        ];
    }

    /** Fetch one ECG the current user is allowed to see, or null. */
    protected function findScopedEcg(int $id, bool $withReport = false)
    {
        return $this->ecgBaseQuery($withReport)->where('pdfs.id', $id)->first();
    }
}
