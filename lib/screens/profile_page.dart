import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/seedling_post_service.dart';
import 'sell_seedling_page.dart';

class ProfilePage extends StatefulWidget {
  final String fullName;
  final String email;
  final String phone;
  final String location;

  const ProfilePage({
    super.key,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.location,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _loading = true;
  bool _isUploading = false;
  bool _isSavingProfile = false;
  String? _error;
  List<SeedlingPost> _myPosts = [];

  late String _fullName;
  late String _email;
  late String _phone;
  late String _location;

  File? _localProfileImage;
  String? _serverImageUrl;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _editNameController = TextEditingController();
  final TextEditingController _editEmailController = TextEditingController();
  final TextEditingController _editPhoneController = TextEditingController();
  final TextEditingController _editLocationController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _fullName = widget.fullName;
    _email = widget.email;
    _phone = widget.phone;
    _location = widget.location;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadSavedProfilePic();
    await _refreshProfilePhotoFromServer();
    await _loadMyProducts();
  }

  Future<void> _refreshProfilePhotoFromServer() async {
    try {
      final serverUrl =
          await SeedlingPostService.instance.fetchProfilePhotoUrl();
      if (serverUrl != null && serverUrl.isNotEmpty && mounted) {
        final prefs = await SharedPreferences.getInstance();
        final sanitizedUrl =
            serverUrl.replaceAll('/storage/storage/', '/storage/');
        await prefs.setString('profile_photo_path', sanitizedUrl);
        setState(() {
          _serverImageUrl = sanitizedUrl;
        });
      }
    } catch (_) {
      // ignore errors; we keep cached photo (if any)
    }
  }

  Future<void> _loadSavedProfilePic() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('profile_photo_path');
    if (savedUrl != null && savedUrl.isNotEmpty && mounted) {
      setState(() {
        _serverImageUrl = savedUrl;
      });
    }
  }

  Future<void> _loadMyProducts() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts = await SeedlingPostService.instance.fetchMyPosts();
      if (mounted) {
        setState(() => _myPosts = posts);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _changeProfilePic() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (pickedFile == null) {
        return;
      }

      setState(() {
        _localProfileImage = File(pickedFile.path);
        _isUploading = true;
      });

      final String newUrl =
          await SeedlingPostService.instance.updateProfilePicture(pickedFile);

      if (newUrl.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        String sanitizedUrl =
            newUrl.replaceAll('/storage/storage/', '/storage/');
        await prefs.setString('profile_photo_path', sanitizedUrl);

        if (mounted) {
          setState(() {
            _serverImageUrl = sanitizedUrl;
            _localProfileImage = null;
            _isUploading = false;
          });
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Upload Successful'),
              content: const Text('Your profile photo was updated.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK')),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Update failed: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF2E7D32);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F0),
      body: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: CircleAvatar(
              radius: 100,
              backgroundColor: themeColor.withValues(alpha: 0.1),
            ),
          ),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(themeColor),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildGlassStats(),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Text(
                            'Account Information',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B5E20)),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _openEditProfile,
                            icon: const Icon(Icons.edit,
                                size: 16, color: Color(0xFF2E7D32)),
                            label: const Text('Edit',
                                style: TextStyle(
                                    color: Color(0xFF2E7D32),
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildGlassInfoCard(),
                      const SizedBox(height: 24),
                      _buildPostButton(),
                      const SizedBox(height: 32),
                      _buildPostHeader(),
                      const SizedBox(height: 16),
                      _buildPostsSection(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(Color color) {
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: color,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, const Color(0xFF1B5E20), const Color(0xFF43A047)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        shape: BoxShape.circle),
                    child: CircleAvatar(
                      radius: 55,
                      backgroundColor: Colors.white,
                      child: ClipOval(child: _buildProfileImageWidget(color)),
                    ),
                  ),
                  if (_isUploading)
                    const Positioned.fill(
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 3),
                    ),
                  Positioned(
                      bottom: 0, right: 4, child: _buildCameraButton(color)),
                ],
              ),
              const SizedBox(height: 12),
              Text(_fullName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              _buildBadge(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImageWidget(Color color) {
    if (_localProfileImage != null) {
      return Image.file(_localProfileImage!,
          fit: BoxFit.cover, width: 110, height: 110);
    }
    if (_serverImageUrl != null && _serverImageUrl!.isNotEmpty) {
      final displayUrl = _withCacheBuster(_serverImageUrl!);
      return Image.network(
        displayUrl,
        fit: BoxFit.cover,
        width: 110,
        height: 110,
        errorBuilder: (context, error, stackTrace) =>
            _profilePlaceholder(color),
      );
    }
    return _profilePlaceholder(color);
  }

  String _withCacheBuster(String url) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return url.contains('?') ? '$url&t=$ts' : '$url?t=$ts';
  }

  Widget _profilePlaceholder(Color color) {
    return Center(
      child: Text(
        _fullName.isNotEmpty ? _fullName[0].toUpperCase() : '?',
        style:
            TextStyle(fontSize: 38, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: const Text("VERIFIED MERCHANT",
          style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1)),
    );
  }

  Widget _buildGlassStats() {
    return _glassContainer(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statColumn('Listings', _myPosts.length.toString()),
          _statDivider(),
          _statColumn('Reputation', '4.9'),
          _statDivider(),
          _statColumn('Rank', 'Pro'),
        ],
      ),
    );
  }

  Widget _buildGlassInfoCard() {
    return _glassContainer(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          _infoTile(Icons.email_rounded, _email, "Email Address"),
          _infoTile(Icons.phone_rounded, _phone, "Phone Number"),
          _infoTile(
              Icons.location_on_rounded, _location, "Business Location",
              isLast: true),
        ],
      ),
    );
  }

  Widget _glassContainer({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding ?? const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String value, String label,
      {bool isLast = false}) {
    return Column(
      children: [
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: const Color(0xFF2E7D32), size: 22),
          ),
          title: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold)),
          subtitle: Text(value,
              style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black,
                  fontWeight: FontWeight.w600)),
        ),
        if (!isLast)
          Divider(
              indent: 70,
              endIndent: 20,
              color: Colors.grey.withValues(alpha: 0.1)),
      ],
    );
  }

  Widget _buildPostsSection() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF2E7D32)));
    }
    if (_error != null) {
      return _statusPlaceholder(_error!, Icons.error_outline, Colors.red);
    }
    if (_myPosts.isEmpty) {
      return _statusPlaceholder("No listings found.",
          Icons.energy_savings_leaf_outlined, Colors.grey);
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _myPosts.length,
      itemBuilder: (context, index) => _myProductCard(_myPosts[index]),
    );
  }

  Widget _buildCameraButton(Color color) => InkWell(
        onTap: _changeProfilePic,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration:
              const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: Icon(Icons.camera_alt_rounded, color: color, size: 20),
        ),
      );

  Widget _statDivider() =>
      Container(height: 30, width: 1, color: Colors.black12);

  Widget _statColumn(String label, String value) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20))),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      );

  Widget _buildPostButton() => SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16))),
          onPressed: () => Navigator.pushNamed(context, '/sell_seedling')
              .then((_) => _loadMyProducts()),
          label: const Text('Post New Seedling',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ),
      );

  Widget _buildPostHeader() => Row(
        children: [
          const Icon(Icons.inventory_2_outlined,
              color: Color(0xFF1B5E20), size: 20),
          const SizedBox(width: 8),
          const Text('My Listings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('${_myPosts.length} items',
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ],
      );

  Widget _myProductCard(SeedlingPost post) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child:
                SizedBox(width: 50, height: 50, child: _buildPostImage(post)),
          ),
          title: Text(post.coconutVariety,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('₱${post.price}',
              style: const TextStyle(
                  color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SellSeedlingPage(post: post),
                  ),
                ).then((_) => _loadMyProducts());
              } else if (value == 'delete') {
                _confirmDelete(post.id);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ),
      );

  Widget _buildPostImage(SeedlingPost post) {
    if (post.imageUrl == null || post.imageUrl!.isEmpty) {
      return const Icon(Icons.image, color: Colors.grey);
    }
    return Image.network(
      post.imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image, color: Colors.grey)),
    );
  }

  Future<void> _confirmDelete(int? postId) async {
    if (postId == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete?'),
        content: const Text('Remove this listing?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes')),
        ],
      ),
    );
    if (confirmed == true) {
      await SeedlingPostService.instance.deletePost(postId);
      _loadMyProducts();
    }
  }

  Future<void> _openEditProfile() async {
    _editNameController.text = _fullName;
    _editEmailController.text = _email;
    _editPhoneController.text = _phone;
    _editLocationController.text = _location;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Edit Profile',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildEditField(
                    controller: _editNameController,
                    label: 'Full Name',
                    icon: Icons.person_outline),
                const SizedBox(height: 12),
                _buildEditField(
                    controller: _editEmailController,
                    label: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _buildEditField(
                    controller: _editPhoneController,
                    label: 'Phone Number',
                    icon: Icons.phone_android_outlined,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _buildEditField(
                    controller: _editLocationController,
                    label: 'Business Location',
                    icon: Icons.location_on_outlined),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed:
                            _isSavingProfile ? null : () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            _isSavingProfile ? null : () => _saveProfile(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                        ),
                        child: _isSavingProfile
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF2E7D32)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: const Color(0xFFF7F9F7),
      ),
    );
  }

  Future<void> _saveProfile(BuildContext sheetContext) async {
    final name = _editNameController.text.trim();
    final email = _editEmailController.text.trim();
    final phone = _editPhoneController.text.trim();
    final location = _editLocationController.text.trim();

    if (name.isEmpty || email.isEmpty || phone.isEmpty) {
      _showProfileSnack('Please fill in all required fields.');
      return;
    }

    if (phone.length < 11) {
      _showProfileSnack('Please enter a valid 11-digit phone number.');
      return;
    }

    setState(() => _isSavingProfile = true);
    try {
      final response = await ApiService.updateProfile(
        fullName: name,
        email: email,
        phoneNumber: phone,
        location: location,
      );

      final seller = response['seller'] ?? response['user'] ?? response['data'];
      final newName = (seller?['full_name'] ?? name).toString();
      final newEmail = (seller?['email'] ?? email).toString();
      final newPhone = (seller?['phone_number'] ?? phone).toString();
      final newLocation = (seller?['location'] ?? location).toString();

      if (!mounted) return;
      setState(() {
        _fullName = newName;
        _email = newEmail;
        _phone = newPhone;
        _location = newLocation;
      });

      if (sheetContext.mounted) {
        Navigator.pop(sheetContext);
      }
      _showProfileSnack('Profile updated successfully!', success: true);
    } catch (e) {
      _showProfileSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  void _showProfileSnack(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            success ? const Color(0xFF2E7D32) : Colors.redAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _editNameController.dispose();
    _editEmailController.dispose();
    _editPhoneController.dispose();
    _editLocationController.dispose();
    super.dispose();
  }

  Widget _statusPlaceholder(String text, IconData icon, Color color) => Center(
        child: Column(
          children: [
            Icon(icon, size: 40, color: color.withValues(alpha: 0.3)),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(color: color.withValues(alpha: 0.6))),
          ],
        ),
      );
}
