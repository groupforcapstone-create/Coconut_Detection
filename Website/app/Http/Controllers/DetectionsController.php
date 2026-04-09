<?php

namespace App\Http\Controllers;

use App\Models\Detections;
use Illuminate\Support\Facades\Http;
use Illuminate\Http\Request;

class DetectionsController extends Controller
{
    public function index()
    {
        $aiStatus = 'Checking...';
        $heartbeatPayload = [
            'model' => 'Unknown',
            'status' => 'AI Server Unknown',
            'timestamp' => now()->toIso8601String(),
        ];
        try {
            $response = Http::retry(2, 750)->timeout(8)->get('https://coconut-ai-backend.onrender.com/');
            $aiStatus = $response->successful() ? 'Live' : 'Maintenance';
            if ($response->ok()) {
                $json = $response->json();
                if (is_array($json)) {
                    $heartbeatPayload = array_merge($heartbeatPayload, $json);
                    if (!empty($json['ai_model_status'])) {
                        $aiStatus = $json['ai_model_status'];
                    }
                }
            }
        } catch (\Exception $e) {
            $message = strtolower($e->getMessage());
            $aiStatus = (str_contains($message, 'timed out') || str_contains($message, 'cURL error 28'))
                ? 'Waking'
                : 'Sleeping';
        }

        return view('detections.index', compact('aiStatus', 'heartbeatPayload'));
    }

    public function wake(Request $request)
    {
        $aiStatus = 'Checking...';
        try {
            $response = Http::retry(2, 1000)->timeout(20)->get('https://coconut-ai-backend.onrender.com/');
            $aiStatus = $response->successful() ? 'Live' : 'Maintenance';
            if ($response->ok()) {
                $json = $response->json();
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
        ]);
    }
}
