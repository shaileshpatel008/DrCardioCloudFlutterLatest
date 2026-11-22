<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use App\Http\Middleware\CheckRoles;
use App\Http\Middleware\AccessAdmin;
use App\Http\Middleware\APIToken;
use App\Http\Middleware\ApiRole;
use App\Http\Middleware\ForceJsonResponse;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware) {
        $middleware->alias([
            'checkRoles' => CheckRoles::class,
            'auth.admin' => AccessAdmin::class,     
            'apitoken'=> APIToken::class,
            'apiRole' => ApiRole::class,
            'forceJson' => ForceJsonResponse::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions) {
        //
    })->create();
