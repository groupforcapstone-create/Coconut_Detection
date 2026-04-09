<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\AdminApiController;
use App\Http\Controllers\Api\SellersApiController;
use App\Http\Controllers\Api\SellerProductApiController;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
*/

// ---------------- PUBLIC ROUTES ----------------
Route::post('/admin/login', [AdminApiController::class, 'login']);
Route::post('/seller/register', [SellersApiController::class, 'register']);
Route::post('/seller/login', [SellersApiController::class, 'login']);
Route::post('/seller/otp/request', [SellersApiController::class, 'requestOtp']);
Route::post('/seller/forgot-password', [SellersApiController::class, 'resetPasswordWithOtp']);

Route::get('/products', [SellerProductApiController::class, 'index']);
Route::get('/products/{id}', [SellerProductApiController::class, 'show']);
Route::get('/varieties', [SellerProductApiController::class, 'varieties']);
Route::get('/coconut-varieties', [SellerProductApiController::class, 'varieties']);

// ---------------- PROTECTED ROUTES ----------------
Route::middleware(['auth:sanctum'])->group(function () {

    // Admin-only routes
    Route::middleware(['admin'])->prefix('admin')->group(function () {
        Route::get('/dashboard', [AdminApiController::class, 'dashboard']);
        Route::get('/sellers', [AdminApiController::class, 'sellers']);
        Route::post('/sellers', [AdminApiController::class, 'storeSeller']);
        Route::put('/sellers/{id}', [AdminApiController::class, 'updateSeller']);
        Route::delete('/sellers/{id}', [AdminApiController::class, 'deleteSeller']);
    });

    // Seller-only routes
    Route::prefix('seller')->group(function () {
        Route::get('/all', [SellersApiController::class, 'index']);
        Route::get('/profile', [SellersApiController::class, 'profile']);
        Route::put('/profile/update', [SellersApiController::class, 'updateProfile']);
        
        // --- NEW ROUTE FOR PROFILE PHOTO ---
        Route::post('/profile/update-photo', [SellersApiController::class, 'updatePhoto']);

        // Scan history (store + list)
        Route::post('/scan-history', [SellersApiController::class, 'storeScanHistory']);
        Route::get('/scan-history', [SellersApiController::class, 'scanHistory']);

        Route::get('/products', [SellerProductApiController::class, 'myProducts']);
        Route::post('/products', [SellerProductApiController::class, 'store']);
        Route::post('/products/{id}', [SellerProductApiController::class, 'update']);
        Route::put('/products/{id}', [SellerProductApiController::class, 'update']);
        Route::delete('/products/{id}', [SellerProductApiController::class, 'destroy']);
        Route::post('/logout', [SellersApiController::class, 'logout']);
    });

    Route::post('/logout', function () {
        auth()->user()->tokens()->delete();
        return response()->json(['message' => 'Logged out successfully']);
    });
});

Route::fallback(function () {
    return response()->json([
        'status' => 'error',
        'message' => 'API Endpoint not found. Check your URL and /api/ prefix.'
    ], 404);
});
