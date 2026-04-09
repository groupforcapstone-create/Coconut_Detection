<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Products;
use App\Models\Sellers;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

class SellerProductApiController extends Controller
{
    // Pre-defined coconut variety metadata
    private const VARIETIES = [
        'Baybay Tall Coconut' => [
            'lifespan' => '80-100 years',
            'definition' => 'Tall coconut variety known for high yield.',
        ],
        'Catigan Dwarf Coconut' => [
            'lifespan' => '50-70 years',
            'definition' => 'Early-bearing dwarf coconut variety.',
        ],
        'Tacunan Dwarf Coconut' => [
            'lifespan' => '50-70 years',
            'definition' => 'Compact dwarf coconut ideal for dense planting.',
        ],
    ];

    /**
     * GET ALL PRODUCTS: For the main Marketplace view.
     * Includes search by variety, location, or definition.
     */
    public function index(Request $request)
    {
        $search = trim((string) $request->query('search', ''));
        $variety = trim((string) $request->query('variety', ''));

        $products = Products::query()
            // Eager load seller info to avoid "N+1" performance issues
            ->with(['seller:id,full_name,email,phone_number,profile_photo_path'])
            ->where('is_active', true)
            ->when($variety !== '', function ($query) use ($variety) {
                $query->where('coconut_variety', 'LIKE', "%{$variety}%");
            })
            ->when($search !== '', function ($query) use ($search) {
                $query->where(function ($q) use ($search) {
                    $q->where('coconut_variety', 'LIKE', "%{$search}%")
                      ->orWhere('location', 'LIKE', "%{$search}%") 
                      ->orWhere('definition', 'LIKE', "%{$search}%");
                });
            })
            ->latest()
            ->get();

        return response()->json($products);
    }

    /**
     * MY PRODUCTS: For the Seller's personal management view.
     */
    public function myProducts(Request $request)
    {
        $seller = $this->resolveSeller($request);
        
        $products = Products::where('seller_id', $seller->id)
            ->with('seller:id,full_name,email,phone_number,profile_photo_path')
            ->latest()
            ->get();
            
        return response()->json($products);
    }
    /**
     * STORE: Save a new seedling post from the Flutter app.
     */
    public function store(Request $request)
    {
        $seller = $this->resolveSeller($request);

        // Validation ensures price and quantity are numeric/integers
        $validated = $request->validate([
            'coconut_variety' => ['required', Rule::in(array_keys(self::VARIETIES))],
            'price' => 'required|numeric|min:0',
            'quantity' => 'required|integer|min:1',
            'location' => 'required|string|max:255', // Now matches the new DB column
            'image' => 'nullable|image|max:25600',   // Up to 25MB
        ]);

        $varietyMeta = self::VARIETIES[$validated['coconut_variety']];
        $imagePath = $this->storeImage($request);

        // Create the product record
        $product = Products::create([
            'seller_id' => $seller->id,
            'coconut_variety' => $validated['coconut_variety'],
            'lifespan' => $varietyMeta['lifespan'],
            'definition' => $varietyMeta['definition'],
            'price' => $validated['price'],
            'quantity' => $validated['quantity'],
            'location' => $validated['location'], 
            'image_path' => $imagePath,
            'is_active' => true,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'Seedling listed successfully!',
            'product' => $product->load('seller:id,full_name,phone_number'),
        ], 201);
    }

    /**
     * UPDATE: Edit an existing seedling post.
     */
    public function update(Request $request, $id)
    {
        $seller = $this->resolveSeller($request);

        $product = Products::where('id', $id)
            ->where('seller_id', $seller->id)
            ->firstOrFail();

        $validated = $request->validate([
            'coconut_variety' => ['required', Rule::in(array_keys(self::VARIETIES))],
            'price' => 'required|numeric|min:0',
            'quantity' => 'required|integer|min:1',
            'location' => 'required|string|max:255',
            'image' => 'nullable|image|max:25600',
        ]);

        $varietyMeta = self::VARIETIES[$validated['coconut_variety']];

        // If a new image is uploaded, replace the old one
        if ($request->hasFile('image')) {
            if ($product->image_path) {
                Storage::disk('public')->delete($product->image_path);
            }
            $product->image_path = $this->storeImage($request);
        }

        $product->coconut_variety = $validated['coconut_variety'];
        $product->lifespan = $varietyMeta['lifespan'];
        $product->definition = $varietyMeta['definition'];
        $product->price = $validated['price'];
        $product->quantity = $validated['quantity'];
        $product->location = $validated['location'];
        $product->save();

        return response()->json([
            'status' => 'success',
            'message' => 'Seedling post updated successfully!',
            'product' => $product->load('seller:id,full_name,phone_number'),
        ], 200);
    }

    /**
     * DELETE: Remove a post and its associated image file.
     */
    public function destroy(Request $request, $id)
    {
        $seller = $this->resolveSeller($request);

        $product = Products::where('id', $id)
            ->where('seller_id', $seller->id)
            ->firstOrFail();

        // Clean up physical file to save server space
        if ($product->image_path) {
            Storage::disk('public')->delete($product->image_path);
        }

        $product->delete();

        return response()->json(['message' => 'Product removed from inventory.']);
    }

    /**
     * HELPER: Verify that the authenticated user is actually a Seller.
     */
    private function resolveSeller(Request $request): Sellers
    {
        $user = $request->user();
        if (!$user instanceof Sellers) {
            abort(response()->json(['message' => 'Unauthorized. Seller account required.'], 403));
        }
        return $user;
    }

    /**
     * HELPER: Save uploaded image to 'public/products' folder.
     */
    private function storeImage(Request $request): ?string
    {
        if ($request->hasFile('image')) {
            // Returns path like: "products/filename.jpg"
            return $request->file('image')->store('products', 'public');
        }
        return null;
    }
}
