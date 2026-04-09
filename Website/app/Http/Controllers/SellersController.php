<?php

namespace App\Http\Controllers;

use App\Models\Sellers;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Auth;

class SellersController extends Controller
{
    /**
     * API: Update Profile Photo from the Mobile App
     * This handles the multipart/form-data request from Flutter
     */
    public function updateProfilePhoto(Request $request)
    {
        // 1. Validate the incoming file
        $request->validate([
            'profile_photo' => 'required|image|mimes:jpeg,png,jpg,gif|max:2048',
        ]);

        // 2. Get the authenticated seller
        // Note: Ensure your Flutter app is sending the Bearer Token
        $user = Auth::user(); 
        
        if (!$user) {
            return response()->json(['message' => 'Unauthorized access'], 401);
        }

        try {
            if ($request->hasFile('profile_photo')) {
                // 3. Delete the old photo from storage if it exists to save space
                if ($user->profile_photo_path) {
                    // Remove 'storage/' from the string if it was accidentally saved
                    $oldPath = str_replace('storage/', '', $user->profile_photo_path);
                    Storage::disk('public')->delete($oldPath);
                }

                // 4. Save the new photo to 'storage/app/public/profiles'
                // The store() method returns the path: "profiles/filename.jpg"
                $path = $request->file('profile_photo')->store('profiles', 'public');

                /** * 5. Update the path in the database
                 * We save ONLY the path "profiles/filename.jpg" 
                 * We do NOT include 'storage/' here to avoid double-pathing issues.
                 */
                $user->update([
                    'profile_photo_path' => $path
                ]);

                return response()->json([
                    'message' => 'Profile photo updated successfully!',
                    'photo_url' => asset('storage/' . $path) // Full URL for Flutter to display
                ], 200);
            }
        } catch (\Exception $e) {
            return response()->json(['message' => 'Upload failed: ' . $e->getMessage()], 500);
        }
    }

    /**
     * Display the list of all Sellers in the Admin Web Portal
     */
    public function index(Request $request)
    {
        $search = trim((string) $request->query('search', ''));

        $sellers = Sellers::query()
            ->when($search !== '', function ($query) use ($search) {
                $query->where(function ($sellerQuery) use ($search) {
                    $sellerQuery->where('full_name', 'like', "%{$search}%")
                        ->orWhere('email', 'like', "%{$search}%")
                        ->orWhere('location', 'like', "%{$search}%")
                        ->orWhere('phone_number', 'like', "%{$search}%");
                });
            })
            ->latest()
            ->paginate(10)
            ->withQueryString();

        return view('sellers.index', compact('sellers', 'search'));
    }

    /**
     * Display details of a specific Seller
     * Includes their profile info and inventory
     */
    public function show($id)
    {
        // Use with('products') to eager load the inventory and avoid 0 items issue
        $seller = Sellers::with('products')->findOrFail($id);
        return view('sellers.detail', compact('seller'));
    }

    /**
     * Remove a Seller and their associated files
     */
    public function destroy($id)
    {
        $seller = Sellers::findOrFail($id);
        
        // Delete the physical image file before deleting the database record
        if ($seller->profile_photo_path) {
            $cleanPath = str_replace('storage/', '', $seller->profile_photo_path);
            Storage::disk('public')->delete($cleanPath);
        }

        $seller->delete();

        return redirect()->route('sellers.index')
                         ->with('success', 'Seller "' . $seller->full_name . '" has been removed.');
    }
}
