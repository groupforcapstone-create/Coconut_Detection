import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/seedling_post_service.dart';

class ProductDetailsPage extends StatefulWidget {
  // Made nullable so it doesn't crash when called from HomeTabs without data
  final SeedlingPost? post;

  const ProductDetailsPage({super.key, this.post});

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  // Function to launch the phone dialer
  Future<void> _makeCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      }
    } catch (e) {
      debugPrint('Call Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- 1. NULL CHECK (Marketplace View) ---
    // If post is null (e.g., accessed via the Bottom Nav Bar), show placeholder.
    if (widget.post == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Marketplace"),
          backgroundColor: const Color(0xFF2E7D32),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.storefront, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text("Select a seedling from the Home Page to view details."),
            ],
          ),
        ),
      );
    }

    // --- 2. DETAILS VIEW (Product Detail View) ---
    // If post is NOT null, show the actual product information.
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true, // Allows content to flow behind the floating navbar
      appBar: AppBar(
        title: const Text("Product Details",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.only(bottom: 120), // Space for floating navbar
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section with Hero Animation
            Hero(
              tag: 'img-${widget.post!.id}',
              child: Container(
                height: 320,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  image: widget.post!.imageUrl != null &&
                          widget.post!.imageUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(widget.post!.imageUrl!),
                          fit: BoxFit.cover)
                      : null,
                ),
                child: (widget.post!.imageUrl == null ||
                        widget.post!.imageUrl!.isEmpty)
                    ? const Icon(Icons.image_not_supported,
                        size: 80, color: Colors.grey)
                    : null,
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Price
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.post!.coconutVariety.toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1B5E20)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "₱${widget.post!.price}",
                          style: const TextStyle(
                              fontSize: 26,
                              color: Colors.green,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Metadata Tags (Location & Stock)
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _buildInfoTag(Icons.location_on, widget.post!.location),
                      _buildInfoTag(
                          Icons.inventory, "Stock: ${widget.post!.quantity}"),
                    ],
                  ),

                  const Divider(height: 40, thickness: 1),

                  // Description Section
                  const Text("Description",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(
                    widget.post!.definition,
                    style: const TextStyle(
                        fontSize: 16, height: 1.5, color: Colors.black87),
                  ),

                  const SizedBox(height: 30),

                  // Seller Information Card
                  _buildSellerCard(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildFloatingNavbar(),
    );
  }

  Widget _buildSellerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF2E7D32),
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Text(widget.post!.sellerName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(widget.post!.sellerEmail),
            trailing: const Icon(Icons.verified, color: Colors.blue, size: 20),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _makeCall(widget.post!.contact),
              icon: const Icon(Icons.phone),
              label: Text("CONTACT: ${widget.post!.contact}",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Floating Navigation Bar implementation
  Widget _buildFloatingNavbar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 65,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                // FIXED: Using .withValues instead of deprecated .withOpacity
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.home_outlined, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
              const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.storefront, color: Colors.white, size: 28),
                  SizedBox(height: 2),
                  CircleAvatar(radius: 2, backgroundColor: Colors.white),
                ],
              ),
              IconButton(
                icon: const CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.camera_alt, color: Colors.white, size: 20),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              IconButton(
                icon:
                    const Icon(Icons.settings_outlined, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.green),
          const SizedBox(width: 5),
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Colors.black54)),
          ),
        ],
      ),
    );
  }
}
