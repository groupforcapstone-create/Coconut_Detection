import 'package:flutter/material.dart';
import '../services/app_endpoints.dart';
import '../services/seedling_post_service.dart';
import 'seller_profile_page.dart';
import 'product_details_page.dart'; // Siguraduhing gawa na ito

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _loadError;
  final themeColor = const Color(0xFF2E7D32);
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;
    setState(() => _loadError = null);
    try {
      await SeedlingPostService.instance.fetchPosts();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String? _imageUrl(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    final p = path.trim();
    if (p.startsWith('http')) return p;
    return AppEndpoints.normalizeUrl(p);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: SeedlingPostService.instance.hasNewPostNotice,
        builder: (context, hasNotice, _) {
          return hasNotice
              ? FloatingActionButton.extended(
                  onPressed: () {
                    _loadProducts();
                    SeedlingPostService.instance.clearNewPostNotice();
                  },
                  backgroundColor: const Color(0xFF1B5E20),
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  label: const Text("SEE NEW POSTS",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w900)),
                )
              : const SizedBox.shrink();
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Stack(
        children: [
          _buildHeaderBackground(),
          RefreshIndicator(
            onRefresh: _loadProducts,
            color: themeColor,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildModernAppBar(),
                _buildWelcomeHeader(),
                if (_loadError != null)
                  SliverToBoxAdapter(child: _buildErrorCard()),

                // Section Title
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                    child: Text("AVAILABLE SEEDLINGS",
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 1.2,
                            color: Colors.grey[800])),
                  ),
                ),

                // Post Grid with Search Filter
                ValueListenableBuilder<List<SeedlingPost>>(
                  valueListenable: SeedlingPostService.instance.posts,
                  builder: (context, posts, _) {
                    // Filter posts based on search query and active status
                    final visiblePosts = posts.where((p) {
                      final matchesSearch = p.coconutVariety
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase());
                      return p.isActive && matchesSearch;
                    }).toList();

                    if (visiblePosts.isEmpty &&
                        !SeedlingPostService.instance.loading.value) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.78,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              _buildGridCard(visiblePosts[index], posts),
                          childCount: visiblePosts.length,
                        ),
                      ),
                    );
                  },
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBackground() {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [themeColor, themeColor.withValues(alpha: 0.8)],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return const SliverAppBar(
      expandedHeight: 60,
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      pinned: true,
      automaticallyImplyLeading: false,
      title: Text("COCOAPP MARKET",
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 2)),
    );
  }

  Widget _buildWelcomeHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Maayong adlaw!",
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
            const Text("High-Quality Seeds",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10)
                  ]),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: const InputDecoration(
                  hintText: "Search coconut variety...",
                  hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                  border: InputBorder.none,
                  icon: Icon(Icons.search, color: Color(0xFF2E7D32)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridCard(SeedlingPost post, List<SeedlingPost> allPosts) {
    final imageUrl = _imageUrl(post.imageUrl);

    return GestureDetector(
      onTap: () {
        // NAVIGATE TO PRODUCT DETAILS
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailsPage(post: post),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(19)),
                    child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: _buildPostImage(post, imageUrl)),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('₱${post.price}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.coconutVariety.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: Color(0xFF1B5E20))),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _openSellerProfile(post, allPosts),
                    child: Row(
                      children: [
                        const Icon(Icons.storefront,
                            size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(post.sellerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors
                                      .green, // Ginawang green para mukhang clickable
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostImage(SeedlingPost post, String? imageUrl) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => _missingImageFill('No Preview'),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        },
      );
    }
    return _missingImageFill('No Image');
  }

  Widget _missingImageFill(String label) {
    return Container(
      color: const Color(0xFFF0F0F0),
      child: Center(
        child: Text(label,
            style: TextStyle(color: Colors.grey[500], fontSize: 10)),
      ),
    );
  }

  void _openSellerProfile(SeedlingPost post, List<SeedlingPost> allPosts) {
    final sellerPosts = allPosts
        .where((p) =>
            p.isActive &&
            (p.sellerId == post.sellerId || p.sellerEmail == post.sellerEmail))
        .toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SellerProfilePage(
            sellerName: post.sellerName,
            sellerEmail: post.sellerEmail,
            sellerId: post.sellerId,
            sellerPhotoUrl: post.sellerPhotoUrl,
            sellerPosts: sellerPosts),
      ),
    );
  }

  Widget _buildErrorCard() => Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.red[50], borderRadius: BorderRadius.circular(20)),
      child: Text('Error: $_loadError',
          style: const TextStyle(color: Colors.red)));

  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text('No seedlings found.',
                style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
}
