import 'package:flutter/material.dart';
import '../services/app_endpoints.dart';
import '../services/seedling_post_service.dart';
import 'product_details_page.dart';
import 'seller_profile_page.dart';

class MarketPage extends StatefulWidget {
  const MarketPage({super.key});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  final SeedlingPostService _service = SeedlingPostService.instance;
  late Future<List<SeedlingPost>> _marketPosts;

  @override
  void initState() {
    super.initState();
    _marketPosts = _fetchInitialData();
  }

  Future<List<SeedlingPost>> _fetchInitialData() async {
    await _service.fetchPosts();
    return _service.posts.value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Matches the clean look
      appBar: AppBar(
        title: const Text("Marketplace",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: FutureBuilder<List<SeedlingPost>>(
        future: _marketPosts,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF2E7D32)));
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No seedlings available."));
          }

          final posts = snapshot.data!;
          final sellerGroups = _groupBySeller(posts);

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _marketPosts = _fetchInitialData();
              });
            },
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: sellerGroups.length,
              itemBuilder: (context, index) {
                final group = sellerGroups[index];
                return _buildSocialPostCard(group, posts);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSocialPostCard(_SellerGroup group, List<SeedlingPost> allPosts) {
    final sellerGallery = _buildSellerGallery(group);
    final varietyNames =
        sellerGallery.map((p) => p.coconutVariety).toSet().take(4).toList();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15), // Slightly smaller radius
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Vital: Keeps the column tight
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header (Smaller scale)
          ListTile(
            dense: true, // Makes the header more compact
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[200],
              backgroundImage: group.primaryPost.sellerPhotoUrl != null
                  ? NetworkImage(group.primaryPost.sellerPhotoUrl!)
                  : null,
              child: group.primaryPost.sellerPhotoUrl == null
                  ? const Icon(Icons.person, size: 20, color: Colors.grey)
                  : null,
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    group.primaryPost.sellerName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.check_circle, color: Colors.blue, size: 12),
              ],
            ),
            subtitle: Text(
              group.primaryPost.location,
              style: const TextStyle(fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.more_horiz, size: 20),
            onTap: () => _openSellerProfile(group, allPosts),
          ),

          // 2. Seller gallery slider
          SellerGallerySlider(
            heroTag: 'img-${group.primaryPost.id}',
            posts: sellerGallery,
            onPostTap: (target) {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ProductDetailsPage(post: target)),
              );
            },
          ),

          // 3. Caption / Details Area (Tighter padding)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "₱${group.primaryPost.price}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.green),
                ),
                const SizedBox(height: 4),
                RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black, fontSize: 12),
                    children: [
                      TextSpan(
                        text: "${group.primaryPost.sellerName} ",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            "selling ${group.primaryPost.coconutVariety}. Stock: ${group.primaryPost.quantity}.",
                      ),
                    ],
                  ),
                ),
                if (varietyNames.isNotEmpty) const SizedBox(height: 8),
                if (varietyNames.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: varietyNames
                        .map((variety) => Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(variety),
                              backgroundColor:
                                  Colors.green.withValues(alpha: 0.12),
                            ))
                        .toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openSellerProfile(_SellerGroup group, List<SeedlingPost> allPosts) {
    final sellerPosts = allPosts
        .where((p) =>
            p.isActive &&
            ((group.sellerId != null && p.sellerId == group.sellerId) ||
                p.sellerEmail == group.sellerEmail))
        .toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SellerProfilePage(
          sellerName: group.sellerName,
          sellerEmail: group.sellerEmail,
          sellerId: group.sellerId,
          sellerPhotoUrl: group.sellerPhotoUrl,
          sellerPosts: sellerPosts,
        ),
      ),
    );
  }

  String? _resolveImageUrl(String? path) {
    return AppEndpoints.normalizeUrl(path?.trim());
  }

  List<SeedlingPost> _buildSellerGallery(_SellerGroup group) {
    final gallery = group.posts.where((post) {
      final url = _resolveImageUrl(post.imageUrl);
      return url != null && url.isNotEmpty;
    }).toList();
    if (gallery.isEmpty) {
      return [group.primaryPost];
    }
    final sorted = [
      group.primaryPost,
      ...gallery.where((p) => p.id != group.primaryPost.id),
    ];
    return sorted.take(5).toList();
  }

  List<_SellerGroup> _groupBySeller(List<SeedlingPost> posts) {
    final grouped = <String, _SellerGroup>{};
    for (var post in posts) {
      final sellerId = post.sellerId;
      final sellerEmail = post.sellerEmail.trim();
      final key = sellerId != null
          ? 'id:$sellerId'
          : sellerEmail.isNotEmpty
              ? 'email:$sellerEmail'
              : 'name:${post.sellerName}';
      final group = grouped.putIfAbsent(
          key,
          () => _SellerGroup(
                sellerId: sellerId,
                sellerName: post.sellerName,
                sellerEmail: post.sellerEmail,
                sellerPhotoUrl: post.sellerPhotoUrl,
                posts: [],
              ));
      group.posts.add(post);
    }
    return grouped.values.toList();
  }
}

class _SellerGroup {
  final int? sellerId;
  final String sellerName;
  final String sellerEmail;
  final String? sellerPhotoUrl;
  final List<SeedlingPost> posts;

  _SellerGroup({
    this.sellerId,
    required this.sellerName,
    required this.sellerEmail,
    this.sellerPhotoUrl,
    required this.posts,
  });

  SeedlingPost get primaryPost => posts.first;
}

class SellerGallerySlider extends StatefulWidget {
  final List<SeedlingPost> posts;
  final void Function(SeedlingPost) onPostTap;
  final String heroTag;

  const SellerGallerySlider({
    super.key,
    required this.posts,
    required this.onPostTap,
    required this.heroTag,
  });

  @override
  State<SellerGallerySlider> createState() => _SellerGallerySliderState();
}

class _SellerGallerySliderState extends State<SellerGallerySlider> {
  late final PageController _controller = PageController();
  int _activeIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final posts = widget.posts;
    return Column(
      children: [
        SizedBox(
          height: 280,
          child: PageView.builder(
            controller: _controller,
            itemCount: posts.length,
            onPageChanged: (index) {
              setState(() => _activeIndex = index);
            },
            itemBuilder: (context, index) {
              final post = posts[index];
              final imageUrl =
                  AppEndpoints.normalizeUrl(post.imageUrl ?? post.imageUrl);
              final image = imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image, color: Colors.grey),
                    )
                  : const Icon(Icons.image, size: 40, color: Colors.grey);

              final child = Hero(
                tag: index == 0 ? widget.heroTag : 'img-${post.id ?? index}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: Colors.grey[100],
                        child: image,
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.center,
                            colors: [
                              Colors.black54,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Text(
                          post.coconutVariety,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black45,
                                blurRadius: 6,
                              )
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );

              return GestureDetector(
                onTap: () => widget.onPostTap(post),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: child,
                ),
              );
            },
          ),
        ),
        if (posts.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                posts.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 6,
                  width: _activeIndex == index ? 20 : 8,
                  decoration: BoxDecoration(
                    color: _activeIndex == index
                        ? const Color(0xFF2E7D32)
                        : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
