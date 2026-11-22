<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

/**
 * API v2: every request is treated as a JSON request, so validation errors
 * come back as 422 JSON and unauthenticated calls as 401 JSON (instead of
 * the web panel's redirects to /login).
 */
class ForceJsonResponse
{
    public function handle(Request $request, Closure $next)
    {
        $request->headers->set('Accept', 'application/json');

        return $next($request);
    }
}
