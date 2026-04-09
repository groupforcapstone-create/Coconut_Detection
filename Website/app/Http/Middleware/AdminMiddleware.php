<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class AdminMiddleware
{
    /**
     * Handle an incoming request.
     */
    public function handle(Request $request, Closure $next)
    {
        // Check if authenticated user is admin
        if ($request->user()->role !== 'admin') {
            return response()->json(['message' => 'Admins only.'], 403);
        }

        return $next($request);
    }
}
