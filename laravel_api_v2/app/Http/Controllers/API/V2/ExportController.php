<?php

namespace App\Http\Controllers\API\V2;

use App\Http\Controllers\API\V2\Concerns\BuildsEcgQueries;
use App\Http\Controllers\PdfsController;
use App\Models\Client;
use Illuminate\Http\Request;

class ExportController extends ApiController
{
    use BuildsEcgQueries;

    /**
     * Records the "Download ECG" tool would export for these filters.
     *
     * Same filters as PdfsController::downloadPdfZip (hospital, staff, date,
     * ECG status). One deliberate fix: the web tool applies no owner scope
     * when "All hospitals" is chosen, so an OEM user or a client exporting
     * "All" received every client's ECGs. Here OEM users only get their own
     * clients and a client only gets their own records. Super Admin keeps
     * the web behaviour (everything).
     */
    private function exportQuery(Request $request)
    {
        $query = $this->ecgBaseQuery(false, false);
        $user = $this->user();

        if ($this->isOemScoped()) {
            $query->where('c.parent_user_id', $user->id);
        } elseif ($user->hasAnyRole('client') && ! $user->hasAnyRoles(['admin', 'sub_admin'])) {
            $query->where('c.user_id', $user->id);
        }

        $filters = new Request($request->only(['hospital_id', 'staff_id', 'ecg_status', 'date_filter', 'from_date', 'to_date']));

        return $this->applyEcgFilters($query, $filters, false);
    }

    /** GET /api/v2/exports/ecg/count — live "N records match" preview. */
    public function count(Request $request)
    {
        return $this->ok(['total' => $this->exportQuery($request)->count()]);
    }

    /**
     * POST /api/v2/exports/ecg {type: pdf|csv, hospital_id, staff_id, ecg_status,
     *   date_filter, from_date, to_date} -> application/zip download.
     */
    public function ecg(Request $request)
    {
        $request->validate(['type' => 'required|in:pdf,csv']);

        set_time_limit(0);
        ini_set('memory_limit', '1024M');

        $rows = $this->exportQuery($request)->get();
        if ($rows->isEmpty()) {
            return $this->fail('No ECG records match these filters.', 404);
        }

        $isPdf = $request->input('type') === 'pdf';
        $fileName = ($isPdf ? 'ECG_Export_' : 'CSV_Export_').now()->format('Ymd_His').'_'.$this->user()->id.'.zip';
        $zipPath = storage_path($fileName);

        $zip = new \ZipArchive();
        if ($zip->open($zipPath, \ZipArchive::CREATE | \ZipArchive::OVERWRITE) !== true) {
            return $this->fail('Failed to create the zip file.', 500);
        }

        foreach ($rows as $row) {
            $base = 'staff/'.$row->staff_id.'/'.$row->document_slug.'/';
            $candidates = [];
            if ($isPdf) {
                $reportName = pathinfo($row->original_file_name, PATHINFO_FILENAME);
                $candidates = [
                    $base.$row->pdf,
                    $base.$reportName.'_cardiologist_report.pdf',
                    $base.$reportName.'_merged_report.pdf',
                ];
            } elseif (! is_null($row->csv_file_name)) {
                $candidates = [$base.'csv_files/'.$row->csv_file_name];
            }
            foreach ($candidates as $relative) {
                $absolute = storage_path('app/public/'.$relative);
                if (file_exists($absolute)) {
                    $zip->addFile($absolute, $relative);
                }
            }
        }

        if ($zip->numFiles === 0) {
            $zip->close();
            @unlink($zipPath);

            return $this->fail($isPdf ? 'No ECG files were found for these records.' : 'No CSV files were found for these records.', 404);
        }

        $zip->close();

        return response()->download($zipPath, $isPdf ? 'ECG_Export.zip' : 'CSV_Export.zip', [
            'Content-Type' => 'application/zip',
        ])->deleteFileAfterSend(true);
    }

    /**
     * POST /api/v2/exports/ecg-counts {month: 01-12, year: YYYY} -> text/csv
     * Cardiologist only; runs PdfsController::downloadExportECGCounts as-is.
     */
    public function ecgCounts(Request $request)
    {
        $request->validate([
            'month' => ['required', 'regex:/^(0[1-9]|1[0-2])$/'],
            'year' => 'required|digits:4',
        ]);

        return app(PdfsController::class)->downloadExportECGCounts($request);
    }
}
