<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

/**
 * API v2 twin of CheckRoles: same rule (admin passes everything, otherwise
 * the user needs one of the listed roles) but answers with 403 JSON instead
 * of redirecting to /login.
 */
class ApiRole
{
    public function handle(Request $request, Closure $next, ...$roles)
    {
        $user = $request->user();

        if (! $user) {
            return response()->json(['status' => 'error', 'message' => 'Unauthenticated.'], 401);
        }

        if ($user->hasAnyRoles(['admin'])) {
            return $next($request);
        }

        foreach ($roles as $role) {
            if ($user->hasAnyRole($role)) {
                return $next($request);
            }
        }

        return response()->json(['status' => 'error', 'message' => 'You do not have access to this section.'], 403);
    }
}
