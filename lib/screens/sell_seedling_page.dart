import 'dart:io' show File;
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../services/seedling_post_service.dart';

class SellSeedlingPage extends StatefulWidget {
  final SeedlingPost? post;
  const SellSeedlingPage({super.key, this.post});

  @override
  State<SellSeedlingPage> createState() => _SellSeedlingPageState();
}

class _SellSeedlingPageState extends State<SellSeedlingPage> {
  static const Map<String, Map<String, String>> _varietyInfo = {
    'Baybay Tall Coconut': {
      'lifespan': '80-100 years',
      'definition': 'Tall coconut variety known for high yield.',
    },
    'Catigan Dwarf Coconut': {
      'lifespan': '50-70 years',
      'definition': 'Early-bearing dwarf coconut variety.',
    },
    'Tacunan Dwarf Coconut': {
      'lifespan': '50-70 years',
      'definition': 'Compact dwarf coconut ideal for dense planting.',
    },
  };

  final ImagePicker _picker = ImagePicker();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  XFile? _selectedImage;
  Uint8List? _webPreview;
  File? _mobilePreview;
  String? _existingImageUrl;
  String _selectedVariety = _varietyInfo.keys.first;
  bool _submitting = false;
  bool _isSearchingLocation = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final post = widget.post;
    if (post != null) {
      _selectedVariety = _varietyInfo.containsKey(post.coconutVariety)
          ? post.coconutVariety
          : _varietyInfo.keys.first;
      _priceController.text = post.price;
      _quantityController.text = post.quantity;
      _locationController.text = post.location;
      _existingImageUrl = post.imageUrl;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (kIsWeb && source == ImageSource.camera) {
      _showSnack('Camera is not available on web.');
      return;
    }

    final picked = await _picker.pickImage(source: source, imageQuality: 70);
    if (picked == null) return;

    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _selectedImage = picked;
        _webPreview = bytes;
        _mobilePreview = null;
      });
    } else {
      setState(() {
        _selectedImage = picked;
        _mobilePreview = File(picked.path);
        _webPreview = null;
      });
    }
  }

  Future<void> _submit() async {
    final price = _priceController.text.trim();
    final quantity = _quantityController.text.trim();
    final location = _locationController.text.trim();

    if (price.isEmpty || quantity.isEmpty || location.isEmpty) {
      _showSnack('Please complete all fields.');
      return;
    }

    final isEdit = widget.post != null;
    if (!isEdit && _selectedImage == null) {
      _showSnack('Please upload a coconut seedling photo.');
      return;
    }

    setState(() => _submitting = true);
    try {
      if (isEdit) {
        final postId = widget.post?.id;
        if (postId == null) {
          _showSnack('Unable to update. Invalid post.');
          return;
        }
        await SeedlingPostService.instance.updatePost(
          id: postId,
          image: _selectedImage,
          coconutVariety: _selectedVariety,
          price: price,
          quantity: quantity,
          location: location,
        );
      } else {
        await SeedlingPostService.instance.createPost(
          image: _selectedImage!,
          coconutVariety: _selectedVariety,
          price: price,
          quantity: quantity,
          location: location,
        );
      }

      if (!mounted) return;
      _showSnack(isEdit ? 'Post updated successfully!' : 'Product uploaded successfully!');
      Navigator.pop(context);
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2E7D32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _priceController.dispose();
    _quantityController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final details = _varietyInfo[_selectedVariety]!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          widget.post != null ? 'Edit Seedling' : 'Post Seedling',
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1B5E20),
                  Color(0xFFE8F5E9),
                  Color(0xFFFFFDE7)
                ],
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
              children: [
                _buildGlassInfoBanner(),
                const SizedBox(height: 20),
                _buildGlassFormCard(details),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassInfoBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2), // FIXED: withValues
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color:
                    Colors.white.withValues(alpha: 0.3)), // FIXED: withValues
          ),
          child: Row(
            children: [
              const Icon(Icons.tips_and_updates_rounded,
                  color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sell your best coconut seedlings to local farmers!',
                  style: TextStyle(
                      color: Colors.white
                          .withValues(alpha: 0.9), // FIXED: withValues
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassFormCard(Map<String, String> details) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7), // FIXED: withValues
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                  color:
                      Colors.white.withValues(alpha: 0.5)), // FIXED: withValues
              boxShadow: [
                BoxShadow(
                    color: Colors.black
                        .withValues(alpha: 0.05), // FIXED: withValues
                    blurRadius: 20,
                    spreadRadius: 5)
              ]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _imagePreview(),
              const SizedBox(height: 15),
              _buildImageButtons(),
              const Divider(height: 40, thickness: 1),
              _buildVarietyDropdown(),
              const SizedBox(height: 12),
              _buildDetailBox(details),
              const SizedBox(height: 20),
              _buildTextField(_priceController, 'Price (PHP)',
                  Icons.payments_rounded, true),
              const SizedBox(height: 15),
              _buildTextField(_quantityController, 'Stock Quantity',
                  Icons.inventory_rounded, true),
              const SizedBox(height: 15),
              _buildLocationAutocomplete(),
              const SizedBox(height: 30),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _pickImage(ImageSource.camera),
            icon: const Icon(Icons.camera_alt_rounded, size: 18),
            label: const Text('Camera'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_rounded, size: 18),
            label: const Text('Gallery'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF2E7D32)),
              foregroundColor: const Color(0xFF2E7D32),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVarietyDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedVariety, // FIXED: initialValue
      decoration: InputDecoration(
        labelText: 'Seedling Variety',
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.5), // FIXED: withValues
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none),
        prefixIcon: const Icon(Icons.eco_rounded, color: Color(0xFF2E7D32)),
      ),
      items: _varietyInfo.keys
          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
          .toList(),
      onChanged: (value) => setState(() => _selectedVariety = value!),
    );
  }

  Widget _buildDetailBox(Map<String, String> details) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            const Color(0xFFF1F8E9).withValues(alpha: 0.8), // FIXED: withValues
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lifespan: ${details['lifespan']}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
          Text('${details['definition']}',
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      IconData icon, bool isNumber) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF2E7D32)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.5), // FIXED: withValues
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildLocationAutocomplete() {
    return LayoutBuilder(
      builder: (context, constraints) => Autocomplete<String>(
        initialValue: TextEditingValue(text: _locationController.text),
        optionsBuilder: (TextEditingValue textEditingValue) async {
          if (textEditingValue.text.length < 3) {
            return const Iterable<String>.empty();
          }

          if (_debounce?.isActive ?? false) {
            _debounce!.cancel();
          }

          final completer = Completer<Iterable<String>>();
          _debounce = Timer(const Duration(milliseconds: 600), () async {
            if (!mounted) {
              return;
            }
            setState(() => _isSearchingLocation = true);
            try {
              final results =
                  await ApiService.searchLocations(textEditingValue.text);
              completer.complete(results);
            } catch (_) {
              completer.complete(const Iterable<String>.empty());
            } finally {
              if (mounted) {
                setState(() => _isSearchingLocation = false);
              }
            }
          });

          return completer.future;
        },
        onSelected: (String selection) {
          _locationController.text = selection;
          FocusScope.of(context).unfocus();
        },
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          controller.addListener(() {
            _locationController.text = controller.text;
          });

          return TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: 'Pick-up Location',
              hintText: 'Type Barangay, City, or Province...',
              prefixIcon: const Icon(Icons.map_rounded,
                  color: Color(0xFF2E7D32)),
              suffixIcon: _isSearchingLocation
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                  : const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none),
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
              child: Container(
                width: constraints.maxWidth,
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final String option = options.elementAt(index);
                    return ListTile(
                      leading: const Icon(Icons.place_outlined,
                          size: 18, color: Colors.grey),
                      title: Text(option, style: const TextStyle(fontSize: 13)),
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubmitButton() {
    final isEdit = widget.post != null;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF2E7D32)
                  .withValues(alpha: 0.3), // FIXED: withValues
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: ElevatedButton(
        onPressed: _submitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: _submitting
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(isEdit ? 'UPDATE POST' : 'POST PRODUCT NOW',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1)),
      ),
    );
  }

  Widget _imagePreview() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5), // FIXED: withValues
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white),
      ),
      child: _selectedImage != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: kIsWeb
                  ? Image.memory(_webPreview!,
                      fit: BoxFit.cover, width: double.infinity)
                  : Image.file(_mobilePreview!,
                      fit: BoxFit.cover, width: double.infinity),
            )
          : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    _existingImageUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.broken_image,
                          size: 50, color: Colors.grey),
                    ),
                  ),
                )
          : const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_rounded,
                    size: 50, color: Color(0xFF2E7D32)),
                SizedBox(height: 10),
                Text('Upload Seedling Photo',
                    style: TextStyle(
                        color: Colors.grey, fontWeight: FontWeight.w500)),
              ],
            ),
    );
  }
}
