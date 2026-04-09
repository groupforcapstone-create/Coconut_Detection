<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use App\Models\User;
use App\Models\Sellers; // Changed from sellers to Sellers

class AdminController extends Controller
{
    /**
     * Constructor to prevent back-button access after logout.
     */
    public function __construct()
    {
        $this->middleware(function ($request, $next) {
            $response = $next($request);
            return $response->header('Cache-Control', 'no-cache, no-store, max-age=0, must-revalidate')
                            ->header('Pragma', 'no-cache')
                            ->header('Expires', 'Sat, 01 Jan 1990 00:00:00 GMT');
        })->except(['showLogin', 'login']);
    }

    /**
     * Show the login form.
     */
    public function showLogin()
    {
        if (Auth::check()) {
            return redirect()->route('dashboard');
        }
        return view('login');
    }

    /**
     * Handle the login authentication logic.
     */
    public function login(Request $request)
    {
        $credentials = $request->validate([
            'email'    => 'required|email',
            'password' => 'required|string',
        ]);

        if (Auth::attempt($credentials)) {
            $request->session()->regenerate();
            
            return redirect()->intended(route('dashboard'));
        }

        return back()->with('error', 'Invalid credentials.');
    }

    /**
     * The Main Dashboard View.
     */
    public function dashboard()
    {
        $this->authorizeAdmin();

        // Fixed: Using Capital S to match your model class
        $totalSellers = Sellers::count();
        $recentSellers = Sellers::latest()->take(6)->get();

        $aiStatus = 'Checking...';
        try {
            $response = Http::retry(2, 750)->timeout(8)->get('https://coconut-ai-backend.onrender.com/');
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

        return view('dashboard', compact('totalSellers', 'recentSellers', 'aiStatus'));
    }

    /**
     * Admin Logout logic.
     */
    public function logout(Request $request)
    {
        Auth::logout();
        
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('login')->withHeaders([
            'Cache-Control' => 'no-cache, no-store, max-age=0, must-revalidate',
            'Pragma' => 'no-cache',
            'Expires' => 'Sat, 01 Jan 1990 00:00:00 GMT',
        ]);
    }

    /**
     * Internal check for admin session.
     */
    private function authorizeAdmin()
    {
        if (!Auth::check()) {
            // Use redirect()->route instead of abort to ensure clean redirection
            redirect()->route('login')->send();
            exit;
        }
    }
}
