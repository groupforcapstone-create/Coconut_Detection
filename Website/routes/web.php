<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AdminController;
use App\Http\Controllers\SellersController;
use App\Http\Controllers\DetectionsController;

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
|
| Handles:
| - Admin login/logout
| - Admin dashboard
| - Sellers CRUD (create, read, update, delete)
|
| All protected routes require authentication and admin role.
|
*/

// ----------------------------
// Root redirect
// ----------------------------
Route::get('/', fn() => redirect()->route('login'));

// ----------------------------
// Admin Login Routes (Public)
// ----------------------------
Route::get('/login', [AdminController::class, 'showLogin'])->name('login');
Route::post('/login', [AdminController::class, 'login'])->name('login.submit');

// ----------------------------
// Protected Routes (Auth + Admin)
// ----------------------------
Route::middleware(['auth'])->group(function () {

    // ----------------------------
    // Admin Dashboard
    // ----------------------------
    Route::get('/admin', [AdminController::class, 'dashboard'])->name('dashboard');

    // ----------------------------
    // Sellers CRUD Routes
    // ----------------------------
    Route::prefix('sellers')->name('sellers.')->group(function () {

        // List all sellers
        Route::get('/', [SellersController::class, 'index'])->name('index');

        // Show create form
        Route::get('/create', [SellersController::class, 'create'])->name('create');

        // Store new seller
        Route::post('/', [SellersController::class, 'store'])->name('store');

        // Show edit form
        Route::get('/{id}/edit', [SellersController::class, 'edit'])->name('edit');

        // Update seller
        Route::put('/{id}', [SellersController::class, 'update'])->name('update');

        // Seller details
        Route::get('/{id}', [SellersController::class, 'show'])->name('detail');

        // Delete seller
        Route::delete('/{id}', [SellersController::class, 'destroy'])->name('destroy');
    });

    // ----------------------------
    // AI Detections Table
    // ----------------------------
    Route::get('/detections', [DetectionsController::class, 'index'])->name('detections.index');
    Route::post('/detections/wake', [DetectionsController::class, 'wake'])->name('detections.wake');
    Route::redirect('/admin/detections', '/detections');
    Route::post('/admin/detections/wake', [DetectionsController::class, 'wake']);

    // ----------------------------
    // Logout
    // ----------------------------
    Route::post('/logout', [AdminController::class, 'logout'])->name('logout');
});
