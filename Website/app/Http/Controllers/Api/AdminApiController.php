<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use App\Models\User;
use App\Models\Sellers; // Updated to Capital S
use App\Models\Detections;
use Illuminate\Validation\ValidationException;

class AdminApiController extends Controller
{
    /**
     * Handle Admin API Login
     * Generates a Sanctum token for the admin user.
     */
    public function login(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
            'password' => 'required',
        ]);

        $user = User::where('email', $request->email)->first();

        // Check if user exists and password is correct
        if (!$user || !Hash::check($request->password, $user->password)) {
            return response()->json([
                'status' => 'error',
                'message' => 'Invalid credentials.'
            ], 401);
        }

        /** * OPTIONAL: If your User model has a 'role' column, 
         * uncomment this to prevent non-admins from logging in here.
         */
        // if ($user->role !== 'admin') { 
        //     return response()->json(['status' => 'error', 'message' => 'Forbidden: Admins only.'], 403); 
        // }

        // Clean up old tokens to prevent bloating the database
        $user->tokens()->delete();

        return response()->json([
            'status' => 'success',
            'message' => 'Login successful',
            'token' => $user->createToken('admin-token')->plainTextToken,
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
            ]
        ]);
    }

    /**
     * API Dashboard Data
     * Accessible via: GET /api/admin/dashboard
     */
    public function dashboard()
    {
        try {
            $aiStatus = 'Checking...';
            try {
                $aiResponse = Http::retry(2, 750)->timeout(8)->get('https://coconut-ai-backend.onrender.com/');
                $aiStatus = $aiResponse->successful() ? 'Live' : 'Maintenance';

                if ($aiResponse->ok()) {
                    $json = $aiResponse->json();
                    if (is_array($json) && !empty($json['ai_model_status'])) {
                        $aiStatus = $json['ai_model_status'];
                    }
                }
            } catch (\Exception $e) {
                $message = strtolower($e->getMessage());
                $aiStatus = (str_contains($message, 'timed out') || str_contains($message, 'cURL error 28'))
                    ? 'Waking'
                    : 'Sleeping';
            }

            return response()->json([
                'status' => 'success',
                'ai_model_status' => $aiStatus,
                'data' => [
                    'total_sellers' => Sellers::count(),
                    // Using 'id' as a basic check for existence
                    'active_sellers' => Sellers::whereNotNull('email')->count(), 
                    'recent_sellers' => Sellers::latest()->take(5)->get()->map(function($seller) {
                        return [
                            'id' => $seller->id,
                            'name' => $seller->full_name,
                            'location' => $seller->location,
                            'joined' => $seller->created_at ? $seller->created_at->diffForHumans() : 'N/A',
                        ];
                    }),
                    'recent_scans' => Detections::latest()->take(5)->get()->map(function($scan) {
                        $confidence = (float) $scan->confidence;
                        $confidencePct = $confidence <= 1 ? round($confidence * 100, 2) : round($confidence, 2);

                        return [
                            'id' => $scan->id,
                            'variety' => $scan->variety_name,
                            'confidence' => $confidencePct . '%',
                            'scanned_at' => $scan->created_at ? $scan->created_at->format('M d, Y h:i A') : 'N/A',
                            'address' => $scan->address ?? 'N/A',
                        ];
                    }),
                ]
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'status' => 'error',
                'message' => 'Could not fetch dashboard data: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Handle Logout
     */
    public function logout(Request $request)
    {
        // Delete the token used for the current session
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'status' => 'success',
            'message' => 'Successfully logged out.'
        ]);
    }
}
