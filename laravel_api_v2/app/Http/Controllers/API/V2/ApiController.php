<?php

namespace App\Http\Controllers\API\V2;

use App\Http\Controllers\Controller;
use App\Models\Cardiologist;
use App\Models\Client;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

/**
 * Shared helpers for the panel's JSON API (v2).
 *
 * The scoping helpers below are copied rule-for-rule from the web
 * controllers (HomeController, ClientController, DeviceController,
 * PdfsController, ...) so the Flutter app sees exactly the same rows a user
 * sees in the Blade panel:
 *  - admin                          -> only rows whose owner is admin (parent_user_id = 0)
 *  - sub_admin with oem_access = 1  -> only rows they own (parent_user_id = their id)
 *  - anyone else                    -> no parent scope (same as the web code)
 */
abstract class ApiController extends Controller
{
    protected function user(): User
    {
        return Auth::user();
    }

    protected function isAdmin(): bool
    {
        return $this->user()->hasAnyRole('admin');
    }

    /** `sub_admin` role AND oem_access = 1 (the check most web controllers use). */
    protected function isOemScoped(): bool
    {
        $u = $this->user();

        return $u->hasAnyRole('sub_admin') && ! is_null($u->oem_access) && (int) $u->oem_access === 1;
    }

    /** oem_access = 1 regardless of role (the looser check some web lookups use). */
    protected function hasOemFlag(): bool
    {
        $u = $this->user();

        return ! is_null($u->oem_access) && (int) $u->oem_access === 1;
    }

    /** Apply the admin / OEM owner scope to a `parent_user_id` column. */
    protected function scopeByParent($query, string $column)
    {
        if ($this->isOemScoped()) {
            $query->where($column, $this->user()->id);
        } elseif ($this->isAdmin()) {
            $query->where($column, 0);
        }

        return $query;
    }

    /** Scope used by the web panel for cardiologist dropdowns. */
    protected function scopeCardiologistOwner($query, string $column = 'cardiologist.parent_user_id')
    {
        $query->where($column, '=', $this->hasOemFlag() ? $this->user()->id : 0);

        return $query;
    }

    /** Can the current admin / OEM user manage this client record? */
    protected function ownsClient(?Client $client): bool
    {
        if (! $client) {
            return false;
        }
        if ($this->isOemScoped()) {
            return (int) $client->parent_user_id === (int) $this->user()->id;
        }

        return true;
    }

    /** Can the current admin / OEM user manage this cardiologist? */
    protected function ownsCardiologist(?Cardiologist $cardiologist): bool
    {
        if (! $cardiologist) {
            return false;
        }
        if ($this->hasOemFlag()) {
            return (int) $cardiologist->parent_user_id === (int) $this->user()->id;
        }

        return true;
    }

    // ---------------------------------------------------------------------
    // Responses
    // ---------------------------------------------------------------------

    protected function ok($data = null, ?string $message = null, array $extra = []): JsonResponse
    {
        $body = ['status' => 'success'];
        if (! is_null($message)) {
            $body['message'] = $message;
        }
        if (! is_null($data)) {
            $body['data'] = $data;
        }

        return response()->json(array_merge($body, $extra));
    }

    protected function fail(string $message, int $code = 422, array $errors = []): JsonResponse
    {
        $body = ['status' => 'error', 'message' => $message];
        if (! empty($errors)) {
            $body['errors'] = $errors;
        }

        return response()->json($body, $code);
    }

    protected function forbidden(string $message = 'You do not have access to this record.'): JsonResponse
    {
        return $this->fail($message, 403);
    }

    /**
     * Translate what an existing web controller action returned into an API
     * response, so create/update/delete keep running through the original,
     * battle-tested code paths:
     *  - redirect (the web "saved" flow)        -> 200 success
     *  - JSON {status: success}                 -> 200 success
     *  - JSON {status: fail}                    -> 403
     *  - JSON 422 field errors (staff dialogs)  -> 422 {message, errors}
     *  - file download                          -> passed through untouched
     */
    protected function fromWeb($response, string $successMessage)
    {
        if ($response instanceof BinaryFileResponse) {
            return $response;
        }
        if ($response instanceof RedirectResponse) {
            return $this->ok(null, $successMessage);
        }
        if ($response instanceof JsonResponse) {
            $payload = $response->getData(true);
            if ($response->getStatusCode() === 422) {
                $first = collect($payload)->flatten()->first() ?? 'The given data was invalid.';

                return $this->fail($first, 422, $payload);
            }
            if (($payload['status'] ?? null) === 'success') {
                return $this->ok(null, $payload['message'] ?? $successMessage);
            }

            return $this->forbidden();
        }
        if (is_string($response)) {
            return $this->fail($response, 422);
        }

        return $response;
    }

    // ---------------------------------------------------------------------
    // Pagination
    // ---------------------------------------------------------------------

    /**
     * Paginate a query builder: ?page=1&per_page=10&sort=name&dir=desc.
     * Only whitelisted sort keys are accepted (mapped to real columns).
     */
    protected function paginate($query, Request $request, array $sortMap, string $defaultSort, callable $map, string $defaultDir = 'desc'): JsonResponse
    {
        $perPage = (int) $request->input('per_page', 10);
        $perPage = in_array($perPage, [10, 25, 50, 100], true) ? $perPage : 10;
        $page = max(1, (int) $request->input('page', 1));
        $sortKey = $request->input('sort', $defaultSort);
        $column = $sortMap[$sortKey] ?? $sortMap[$defaultSort];
        $dir = strtolower((string) $request->input('dir', $defaultDir)) === 'asc' ? 'asc' : 'desc';

        $total = (clone $query)->count();
        $rows = $query->orderBy($column, $dir)
            ->offset(($page - 1) * $perPage)
            ->limit($perPage)
            ->get()
            ->map($map)
            ->values();

        return response()->json([
            'status' => 'success',
            'data' => $rows,
            'meta' => [
                'page' => $page,
                'per_page' => $perPage,
                'total' => $total,
                'last_page' => max(1, (int) ceil($total / $perPage)),
            ],
        ]);
    }

    protected function searchTerm(Request $request): ?string
    {
        $term = trim((string) $request->input('search', ''));

        return $term === '' ? null : $term;
    }

    // ---------------------------------------------------------------------
    // Formatting
    // ---------------------------------------------------------------------

    /** ISO-8601 timestamp in the app timezone (what the Flutter app parses). */
    protected function iso($value): ?string
    {
        if (empty($value)) {
            return null;
        }

        return Carbon::parse($value)->toIso8601String();
    }

    /** Same human format the Blade tables show ("22-11-2026 11:11 AM"). */
    protected function display($value): ?string
    {
        if (empty($value)) {
            return null;
        }

        return date('d-m-Y h:i A', strtotime($value));
    }

    protected function storageUrl(?string $relative): ?string
    {
        if (empty($relative)) {
            return null;
        }

        return url('/storage/'.ltrim($relative, '/'));
    }

    /** Decode a JSON column the mobile app fills (device_info, patient_info). */
    protected function jsonColumn($value)
    {
        if (empty($value) || $value === 'null') {
            return null;
        }
        if (is_array($value) || is_object($value)) {
            return $value;
        }
        $decoded = json_decode($value, true);

        return json_last_error() === JSON_ERROR_NONE ? $decoded : $value;
    }

    protected function cleanString($value): ?string
    {
        if (is_null($value)) {
            return null;
        }
        $value = trim((string) $value);

        return ($value === '' || strtolower($value) === 'null') ? null : $value;
    }
}
