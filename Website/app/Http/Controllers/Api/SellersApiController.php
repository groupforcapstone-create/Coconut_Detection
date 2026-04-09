<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Sellers;
use App\Models\SellerOtp;
use App\Models\ScanHistory;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Carbon;

class SellersApiController extends Controller
{
    /**
     * REGISTER SELLER
     * Creates a new seller account and returns a Sanctum token.
     */
    public function register(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'full_name'    => 'required|string|max:255',
            'email'        => 'required|string|email|max:255|ends_with:gmail.com|unique:sellers,email',
            'phone_number' => 'required|string|size:11|regex:/^09[0-9]{9}$/|unique:sellers,phone_number',
            'password'     => 'required|string|min:8',
            'otp_code'     => 'required|string|size:6',
            'location'     => 'nullable|string',
        ], [
            'phone_number.regex' => 'The phone number must start with 09.',
            'phone_number.size'  => 'The phone number must be exactly 11 digits.',
            'phone_number.unique'=> 'This phone number is already registered.',
            'email.unique'       => 'This email address is already in use.',
            'email.ends_with'    => 'Please use a valid Gmail address (example@gmail.com).',
            'otp_code.size'      => 'OTP must be exactly 6 digits.',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status'  => 'error', 
                'message' => $validator->errors()->first(),
                'errors'  => $validator->errors()
            ], 422);
        }

        try {
            $otpResult = $this->consumeOtp(
                $request->phone_number,
                'register',
                $request->otp_code
            );
            if ($otpResult !== true) {
                return response()->json([
                    'status'  => 'error',
                    'message' => $otpResult
                ], 422);
            }

            $seller = Sellers::create([
                'full_name'    => $request->full_name,
                'email'        => $request->email,
                'phone_number' => $request->phone_number,
                'location'     => $request->location,
                'password'     => Hash::make($request->password),
            ]);

            $token = $seller->createToken('seller_token')->plainTextToken;

            return response()->json([
                'status'  => 'success',
                'message' => 'Account registered successfully!',
                'token'   => $token,
                'seller'  => $seller
            ], 201);

        } catch (\Exception $e) {
            Log::error("Registration Error: " . $e->getMessage());
            return response()->json([
                'status'  => 'error',
                'message' => 'Server Error: ' . $e->getMessage() 
            ], 500);
        }
    }

    /**
     * LOGIN SELLER
     * Validates credentials and provides a fresh Sanctum token.
     */
    public function login(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'login'        => 'nullable',
            'email'        => 'nullable|email',
            'phone_number' => 'nullable',
            'password'     => 'required',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 'error', 
                'message' => 'Please provide both login and password.'
            ], 422);
        }

        $loginValue = $request->input('login')
            ?? $request->input('email')
            ?? $request->input('phone_number');
        if (!$loginValue) {
            return response()->json([
                'status' => 'error',
                'message' => 'Please provide both login and password.'
            ], 422);
        }

        // Allow login using either Email or Phone Number
        $seller = Sellers::where('email', $loginValue)
                        ->orWhere('phone_number', $loginValue)
                        ->first();

        if (!$seller || !Hash::check($request->password, $seller->password)) {
            return response()->json([
                'status' => 'error', 
                'message' => 'Incorrect user or password.'
            ], 401);
        }

        // Allow multiple device sessions by keeping existing tokens.
        $token = $seller->createToken('seller_token')->plainTextToken;

        return response()->json([
            'status'  => 'success',
            'message' => 'Login successful!',
            'token'   => $token,
            'seller'  => $seller
        ], 200);
    }

    /**
     * GET SELLER PROFILE
     * Returns the currently authenticated seller's data.
     */
    public function profile(Request $request)
    {
        $seller = $request->user();
        return response()->json([
            'status' => 'success',
            'seller' => $seller,
            'photo_url' => $seller && $seller->profile_photo_path
                ? 'storage/' . $seller->profile_photo_path
                : null,
        ], 200);
    }

    /**
     * UPDATE SELLER PROFILE
     * Updates account info (name, email, phone, location).
     */
    public function updateProfile(Request $request)
    {
        $seller = $request->user();
        if (!$seller) {
            return response()->json(['status' => 'error', 'message' => 'Unauthorized'], 401);
        }

        $validator = Validator::make($request->all(), [
            'full_name'    => 'required|string|max:255',
            'email'        => 'required|string|email|max:255|ends_with:gmail.com|unique:sellers,email,' . $seller->id,
            'phone_number' => 'required|string|size:11|regex:/^09[0-9]{9}$/|unique:sellers,phone_number,' . $seller->id,
            'location'     => 'nullable|string|max:255',
        ], [
            'phone_number.regex' => 'The phone number must start with 09.',
            'phone_number.size'  => 'The phone number must be exactly 11 digits.',
            'phone_number.unique'=> 'This phone number is already registered.',
            'email.unique'       => 'This email address is already in use.',
            'email.ends_with'    => 'Please use a valid Gmail address (example@gmail.com).',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status'  => 'error',
                'message' => $validator->errors()->first(),
                'errors'  => $validator->errors()
            ], 422);
        }

        $seller->update([
            'full_name'    => $request->input('full_name'),
            'email'        => $request->input('email'),
            'phone_number' => $request->input('phone_number'),
            'location'     => $request->input('location'),
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'Profile updated successfully.',
            'seller' => $seller,
            'photo_url' => $seller->profile_photo_path
                ? 'storage/' . $seller->profile_photo_path
                : null,
        ], 200);
    }

    /**
     * UPDATE SELLER PROFILE PHOTO
     * Handles file upload, deletes old photo, and returns the new storage path.
     */
    public function updatePhoto(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'profile_photo' => 'required|image|mimes:jpeg,png,jpg|max:2048',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 'error',
                'message' => $validator->errors()->first()
            ], 422);
        }

        try {
            $seller = $request->user();

            if ($request->hasFile('profile_photo')) {
                // 1. Delete the old photo if it exists to clean up server space
                if ($seller->profile_photo_path) {
                    // Remove 'storage/' prefix if present before calling delete
                    $oldPath = str_replace('storage/', '', $seller->profile_photo_path);
                    Storage::disk('public')->delete($oldPath);
                }

                // 2. Upload the new file to 'storage/app/public/profiles'
                $path = $request->file('profile_photo')->store('profiles', 'public');

                // 3. Update the database record with the clean path
                $seller->update([
                    'profile_photo_path' => $path
                ]);

                return response()->json([
                    'status' => 'success',
                    'message' => 'Profile picture updated successfully!',
                    /** * FIX: We return 'storage/' + path so the Flutter app 
                     * can easily append it to your Base URL.
                     */
                    'photo_url' => 'storage/' . $path 
                ], 200);
            }

            return response()->json(['status' => 'error', 'message' => 'No file uploaded'], 400);

        } catch (\Exception $e) {
            Log::error("Photo Upload Error: " . $e->getMessage());
            return response()->json([
                'status' => 'error',
                'message' => 'Upload failed: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * STORE SCAN HISTORY
     * Saves scan results and image from the mobile app.
     */
    public function storeScanHistory(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'label' => 'nullable|string|max:255',
            'top_prediction' => 'nullable|string|max:255',
            'confidence_json' => 'nullable|json',
            'address' => 'nullable|string|max:500',
            'scan_image' => 'required|image|mimes:jpeg,png,jpg|max:4096',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 'error',
                'message' => $validator->errors()->first()
            ], 422);
        }

        try {
            $seller = $request->user();
            if (!$seller) {
                return response()->json(['status' => 'error', 'message' => 'Unauthorized'], 401);
            }

            $path = $request->file('scan_image')->store('scans', 'public');
            Log::info('Scan history upload', [
                'seller_id' => $seller->id,
                'label' => $request->input('label'),
                'top_prediction' => $request->input('top_prediction'),
                'address' => $request->input('address'),
                'image_path' => $path,
            ]);

            $confInput = $request->input('confidence_json');
            $confDecoded = null;
            if (is_string($confInput)) {
                $confDecoded = json_decode($confInput, true);
            } elseif (is_array($confInput)) {
                $confDecoded = $confInput;
            }
            if (!is_array($confDecoded)) {
                $confDecoded = null;
            }

            $topPrediction = $request->input('top_prediction');
            if (!$topPrediction && is_array($confDecoded) && count($confDecoded) > 0) {
                $topPrediction = $confDecoded[0]['label'] ?? null;
            }

            $history = ScanHistory::create([
                'seller_id' => $seller->id,
                'label' => $request->input('label'),
                'top_prediction' => $topPrediction,
                'confidence_json' => $confDecoded,
                'address' => $request->input('address'),
                'image_path' => $path,
            ]);

            return response()->json([
                'status' => 'success',
                'message' => 'Scan history saved.',
                'history' => $history,
            ], 201);
        } catch (\Exception $e) {
            Log::error("Scan History Error: " . $e->getMessage());
            return response()->json([
                'status' => 'error',
                'message' => 'Failed to save scan history.'
            ], 500);
        }
    }

    /**
     * GET SCAN HISTORY
     * Returns recent scan history for the authenticated seller.
     */
    public function scanHistory(Request $request)
    {
        $seller = $request->user();
        if (!$seller) {
            return response()->json(['status' => 'error', 'message' => 'Unauthorized'], 401);
        }

        $history = ScanHistory::where('seller_id', $seller->id)
            ->latest()
            ->get()
            ->map(function ($item) {
                return [
                    'id' => $item->id,
                    'label' => $item->label,
                    'top_prediction' => $item->top_prediction,
                    'confidence_json' => $item->confidence_json,
                    'address' => $item->address,
                    'image_url' => $item->image_path ? asset('storage/' . $item->image_path) : null,
                    'created_at' => $item->created_at,
                ];
            });

        return response()->json([
            'status' => 'success',
            'history' => $history,
        ], 200);
    }

    /**
     * LOGOUT SELLER
     * Revokes the current access token.
     */
    public function logout(Request $request)
    {
        try {
            if ($request->user()) {
                $request->user()->currentAccessToken()->delete();
            }

            return response()->json([
                'status' => 'success',
                'message' => 'Logged out successfully'
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'status' => 'error',
                'message' => 'Logout failed: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * REQUEST OTP (REGISTER or RESET)
     * Sends a 6-digit OTP to the user's phone number.
     */
    public function requestOtp(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'phone_number' => 'required|string|size:11|regex:/^09[0-9]{9}$/',
            'purpose'      => 'required|string|in:register,reset',
        ], [
            'phone_number.regex' => 'The phone number must start with 09.',
            'phone_number.size'  => 'The phone number must be exactly 11 digits.',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status'  => 'error',
                'message' => $validator->errors()->first(),
                'errors'  => $validator->errors()
            ], 422);
        }

        $phone = $request->phone_number;
        $purpose = $request->purpose;

        if ($purpose === 'register' && Sellers::where('phone_number', $phone)->exists()) {
            return response()->json([
                'status' => 'error',
                'message' => 'This phone number is already registered.'
            ], 409);
        }

        if ($purpose === 'reset' && !Sellers::where('phone_number', $phone)->exists()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Phone number not found.'
            ], 404);
        }

        $otp = $this->createOtp($phone, $purpose);

        // TODO: Integrate SMS provider here.
        // For now, return OTP only when APP_DEBUG=true
        $payload = [
            'status'  => 'success',
            'message' => 'OTP sent successfully.'
        ];
        if (config('app.debug')) {
            $payload['debug_otp'] = $otp;
        }

        return response()->json($payload, 200);
    }

    /**
     * RESET PASSWORD USING PHONE + OTP
     */
    public function resetPasswordWithOtp(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'phone_number'            => 'required|string|size:11|regex:/^09[0-9]{9}$/',
            'otp_code'                => 'required|string|size:6',
            'new_password'            => 'required|string|min:8|confirmed',
        ], [
            'phone_number.regex' => 'The phone number must start with 09.',
            'phone_number.size'  => 'The phone number must be exactly 11 digits.',
            'otp_code.size'      => 'OTP must be exactly 6 digits.',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status'  => 'error',
                'message' => $validator->errors()->first(),
                'errors'  => $validator->errors()
            ], 422);
        }

        $seller = Sellers::where('phone_number', $request->phone_number)->first();
        if (!$seller) {
            return response()->json([
                'status' => 'error',
                'message' => 'Phone number not found.'
            ], 404);
        }

        $otpResult = $this->consumeOtp(
            $request->phone_number,
            'reset',
            $request->otp_code
        );
        if ($otpResult !== true) {
            return response()->json([
                'status'  => 'error',
                'message' => $otpResult
            ], 422);
        }

        $seller->password = Hash::make($request->new_password);
        $seller->save();

        return response()->json([
            'status' => 'success',
            'message' => 'Password reset successfully.'
        ], 200);
    }

    private function createOtp(string $phoneNumber, string $purpose): string
    {
        SellerOtp::where('phone_number', $phoneNumber)
            ->where('purpose', $purpose)
            ->delete();

        $otp = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);

        SellerOtp::create([
            'phone_number' => $phoneNumber,
            'purpose' => $purpose,
            'code_hash' => Hash::make($otp),
            'expires_at' => Carbon::now()->addMinutes(5),
        ]);

        return $otp;
    }

    private function consumeOtp(string $phoneNumber, string $purpose, string $code)
    {
        $otp = SellerOtp::where('phone_number', $phoneNumber)
            ->where('purpose', $purpose)
            ->whereNull('consumed_at')
            ->orderByDesc('id')
            ->first();

        if (!$otp) {
            return 'OTP not found or expired.';
        }

        if ($otp->expires_at && $otp->expires_at->isPast()) {
            $otp->delete();
            return 'OTP has expired. Please request a new one.';
        }

        if (!Hash::check($code, $otp->code_hash)) {
            return 'Incorrect OTP. Please try again.';
        }

        $otp->consumed_at = Carbon::now();
        $otp->save();

        return true;
    }
}
