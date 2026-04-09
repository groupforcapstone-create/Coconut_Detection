import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/app_endpoints.dart';
import '../services/seedling_post_service.dart';

class SellerProfilePage extends StatelessWidget {
  final String sellerName;
  final String sellerEmail;
  final int? sellerId;
  final List<SeedlingPost> sellerPosts;
  final String? sellerPhotoUrl;

  const SellerProfilePage({
    super.key,
    required this.sellerName,
    required this.sellerEmail,
    required this.sellerId,
    required this.sellerPosts,
    this.sellerPhotoUrl,
  });

  String? _imageUrl(SeedlingPost post) {
    final path = post.imageUrl?.trim() ?? '';
    if (path.isEmpty) return null;
    return AppEndpoints.normalizeUrl(path);
  }

  List<SeedlingPost> _postsWithImages() {
    return sellerPosts.where((post) {
      final url = _imageUrl(post);
      return url != null && url.isNotEmpty;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF2E7D32);
    final String? resolvedPhoto = sellerPhotoUrl ??
        sellerPosts
            .map((p) => p.sellerPhotoUrl)
            .firstWhere((p) => p != null && p.isNotEmpty, orElse: () => null);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F0),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. GRADIENT SLIVER APP BAR
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            stretch: true,
            iconTheme: const IconThemeData(color: Colors.white),
            backgroundColor: themeColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1B5E20),
                      Color(0xFF2E7D32),
                      Color(0xFF4CAF50)
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Colors.white24, shape: BoxShape.circle),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white,
                        backgroundImage: (resolvedPhoto != null &&
                                resolvedPhoto.isNotEmpty)
                            ? NetworkImage(resolvedPhoto)
                            : null,
                        child: (resolvedPhoto == null ||
                                resolvedPhoto.isEmpty)
                            ? const Icon(Icons.storefront_rounded,
                                size: 40, color: Color(0xFF2E7D32))
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      sellerName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      sellerEmail.isEmpty ? 'Verified Seller' : sellerEmail,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. FEATURED PHOTOS (GLASS EFFECT)
          if (_postsWithImages().isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _buildGlassSection(
                  title: 'Featured Photos',
                  child: _photoGrid(context),
                ),
              ),
            ),

          // 3. FULL INVENTORY TITLE
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(22, 10, 22, 10),
              child: Row(
                children: [
                  Icon(Icons.inventory_2_rounded,
                      size: 20, color: Color(0xFF1B5E20)),
                  SizedBox(width: 8),
                  Text(
                    'Full Inventory',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B2E1C)),
                  ),
                ],
              ),
            ),
          ),

          // 4. LISTINGS CARDS
          sellerPosts.isEmpty
              ? SliverFillRemaining(child: _buildEmptyState())
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _listingCard(sellerPosts[index]),
                      childCount: sellerPosts.length,
                    ),
                  ),
                ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // GLASS CONTAINER HELPER
  Widget _buildGlassSection({required String title, required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20))),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _listingCard(SeedlingPost post) {
    final imageUrl = _imageUrl(post);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: _buildPostImage(post, imageUrl),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(post.coconutVariety,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('₱${post.price}',
                        style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(height: 24),
                _infoIconRow(Icons.location_on_outlined, post.location),
                _infoIconRow(
                    Icons.inventory_2_outlined, 'Stock: ${post.quantity}'),
                _infoIconRow(Icons.phone_outlined, post.contact),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoIconRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(color: Colors.grey[800], fontSize: 13))),
        ],
      ),
    );
  }

  Widget _photoGrid(BuildContext context) {
    final imagePosts = _postsWithImages().take(4).toList();
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: imagePosts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final post = imagePosts[index];
        final url = _imageUrl(post);
        return GestureDetector(
          onTap: () => _openImagePreview(context, post, url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.grey[200]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostImage(SeedlingPost post, String? imageUrl) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: imageUrl != null
          ? Image.network(
              imageUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _missingImage('Image unavailable'),
            )
          : _missingImage('No Image Attached'),
    );
  }

  Widget _missingImage(String label) {
    return Container(
      color: const Color(0xFFF1F5F1),
      child: Center(
          child: Text(label, style: const TextStyle(color: Colors.grey))),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text('No active listings found.',
          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
    );
  }

  void _openImagePreview(
      BuildContext context, SeedlingPost post, String? imageUrl) {
    if (imageUrl == null) return;
    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: InteractiveViewer(child: Image.network(imageUrl)),
              ),
              const SizedBox(height: 10),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
        ),
      ),
    );
  }
}
