<?php

namespace App\Http\Controllers\API\V2;

use App\Http\Controllers\API\V2\Concerns\BuildsEcgQueries;
use App\Http\Controllers\PdfsController;
use App\Models\PdfData;
use App\Models\Template;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class EcgRecordController extends ApiController
{
    use BuildsEcgQueries;

    /**
     * GET /api/v2/ecg-records
     *   ?page&per_page&sort=date|staff|hospital|device|status|file&dir
     *   &search&hospital_id&staff_id&device_id&cardiologist_id
     *   &status=pending|requested|reported|no_credit&ecg_status=normal|abnormal
     *   &date_filter=today|yesterday|7|14|30|this_week|last_week|this_month|last_month|custom
     *   &from_date=YYYY-MM-DD&to_date=YYYY-MM-DD
     */
    public function index(Request $request)
    {
        $query = $this->applyEcgFilters($this->ecgBaseQuery(), $request);

        return $this->paginate($query, $request, $this->ecgSortMap(), 'date', fn ($row) => $this->presentEcg($row));
    }

    /** GET /api/v2/ecg-records/summary — counts per report status for the tabs. */
    public function summary(Request $request)
    {
        $query = $this->applyEcgFilters($this->ecgBaseQuery(), $request, false);
        $counts = (clone $query)->reorder()
            ->select(DB::raw('pdfs.status as status'), DB::raw('COUNT(*) as total'))
            ->groupBy('pdfs.status')
            ->pluck('total', 'status');

        $byStatus = [
            'pending' => (int) ($counts['pending'] ?? 0),
            'requested' => (int) ($counts['requested'] ?? 0),
            'reported' => (int) ($counts['reported'] ?? 0),
            'no_credit' => (int) ($counts['no_credit'] ?? 0),
        ];

        return $this->ok([
            'all' => array_sum($byStatus),
            'by_status' => $byStatus,
        ]);
    }

    /** GET /api/v2/ecg-records/{id} */
    public function show(int $id)
    {
        $row = $this->findScopedEcg($id, true);
        if (! $row) {
            return $this->fail('ECG record not found.', 404);
        }

        return $this->ok($this->presentEcg($row, true));
    }

    /** DELETE /api/v2/ecg-records/{id} — admin / OEM only (same as the web). */
    public function destroy(int $id)
    {
        if (! $this->findScopedEcg($id)) {
            return $this->fail('ECG record not found.', 404);
        }

        $response = app(PdfsController::class)->delete(PdfData::findOrFail($id));

        return $this->fromWeb($response, 'ECG record deleted.');
    }

    /** POST /api/v2/ecg-records/{id}/reassign {cardiologist_id} */
    public function reassign(Request $request, int $id)
    {
        $request->validate(['cardiologist_id' => 'required|integer|min:1']);

        $row = $this->findScopedEcg($id);
        if (! $row) {
            return $this->fail('ECG record not found.', 404);
        }
        if ($row->status !== 'requested' || is_null($row->client_cardiologist_id)) {
            return $this->fail('Only requested ECGs from a client with an assigned cardiologist can be re-assigned.');
        }

        $cardiologist = User::find($request->input('cardiologist_id'));
        if (! $cardiologist || ! $cardiologist->hasAnyRole('cardiologist')) {
            return $this->fail('Please choose a valid cardiologist.');
        }

        $request->merge(['cardio_id' => $request->input('cardiologist_id')]);
        $response = app(PdfsController::class)->reAssignCardio(PdfData::findOrFail($id), $request);

        return $this->fromWeb($response, 'ECG re-assigned to '.$cardiologist->name.'.');
    }

    /** POST /api/v2/ecg-records/{id}/assign — send a "no credit" ECG to the client's cardiologist. */
    public function assign(Request $request, int $id)
    {
        $row = $this->findScopedEcg($id);
        if (! $row) {
            return $this->fail('ECG record not found.', 404);
        }
        if ($row->status !== 'no_credit' || is_null($row->client_cardiologist_id)) {
            return $this->fail('This ECG cannot be assigned.');
        }

        $response = app(PdfsController::class)->assignCardio(PdfData::findOrFail($id), $request);

        return $this->fromWeb($response, 'ECG sent to the cardiologist.');
    }

    /** GET /api/v2/ecg-records/{id}/diagnose — what the report editor needs. */
    public function diagnoseForm(int $id)
    {
        $row = $this->findScopedEcg($id, true);
        if (! $row) {
            return $this->fail('ECG record not found.', 404);
        }

        $templates = Template::select('id', 'title', 'body')
            ->where('templates.cardiologist_id', $this->user()->id)
            ->get();

        return $this->ok([
            'record' => $this->presentEcg($row, true),
            'templates' => $templates,
        ]);
    }

    /**
     * POST /api/v2/ecg-records/{id}/diagnose
     *   {action: draft|publish, ecg_status, cardiologist_report, hr, r, rr, pr, qrs, qt, qtc, qt_by_qtc}
     *
     * draft   -> status stays "requested" (web "Save draft")
     * publish -> status "reported": the panel builds the report PDF, merges
     *            it with the ECG and pushes an FCM notification — all done by
     *            PdfsController::pdfDiagnoseStatusChange, reused as-is.
     */
    public function diagnose(Request $request, int $id)
    {
        $request->validate([
            'action' => 'required|in:draft,publish',
            'ecg_status' => 'nullable|in:normal,abnormal,borderline,0',
            'cardiologist_report' => 'nullable|string',
        ]);

        $row = $this->findScopedEcg($id);
        if (! $row) {
            return $this->fail('ECG record not found.', 404);
        }

        $publish = $request->input('action') === 'publish';
        if ($publish && ! in_array($request->input('ecg_status'), ['normal', 'abnormal', 'borderline'], true)) {
            return $this->fail('Please select the ECG status before publishing.', 422, ['ecg_status' => ['Please select the ECG status.']]);
        }

        // Web computes QT/QTc in the browser; do the same here when it is missing.
        if (! $request->filled('qt_by_qtc') && is_numeric($request->input('qt')) && is_numeric($request->input('qtc')) && (float) $request->input('qtc') != 0.0) {
            $request->merge(['qt_by_qtc' => number_format($request->input('qt') / $request->input('qtc'), 2, '.', '')]);
        }

        $response = app(PdfsController::class)->pdfDiagnoseStatusChange(
            PdfData::findOrFail($id),
            $publish ? 'reported' : 'requested',
            $request
        );

        $result = $this->fromWeb($response, $publish ? 'Report published.' : 'Draft saved.');
        if ($result->getStatusCode() === 200) {
            $fresh = $this->findScopedEcg($id, true);

            return $this->ok($fresh ? $this->presentEcg($fresh, true) : null, $publish ? 'Report published.' : 'Draft saved.');
        }

        return $result;
    }
}
