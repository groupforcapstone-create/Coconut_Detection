import 'dart:io';

import 'package:flutter/material.dart';

import '../services/detection_history_store.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<Map<String, dynamic>>> _detectionsFuture;
  final Set<String> _selectedIds = {};

  bool get _isSelecting => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _detectionsFuture = DetectionHistoryStore.instance.getDetections();
  }

  Future<void> _reloadDetections() async {
    setState(() {
      _detectionsFuture = DetectionHistoryStore.instance.getDetections();
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    if (id.isEmpty) return;

    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  String _formatDate(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final displayHour = hour == 0 ? 12 : hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '${date.month}/${date.day}/${date.year} $displayHour:$minute $period';
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
    required String action,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteSelectedHistory() async {
    final count = _selectedIds.length;
    if (count == 0) return;

    final confirmed = await _confirmDelete(
      title: 'Delete selected?',
      message:
          'This will permanently remove $count selected scan${count == 1 ? '' : 's'}.',
      action: 'Delete selected',
    );

    if (!confirmed) return;

    await DetectionHistoryStore.instance.deleteDetectionsByIds(_selectedIds);
    await _reloadDetections();
  }

  Future<void> _clearHistory() async {
    final confirmed = await _confirmDelete(
      title: 'Delete all history?',
      message: 'This will permanently remove every saved scan.',
      action: 'Delete all',
    );

    if (!confirmed) return;

    await DetectionHistoryStore.instance.clearDetections();
    await _reloadDetections();
  }

  void _openFullscreenImage(File imageFile) {
    if (_isSelecting) return;
    if (!imageFile.existsSync()) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FullscreenImagePage(imageFile: imageFile),
      ),
    );
  }

  Widget _buildHeaderActions(List<Map<String, dynamic>> detections) {
    if (_isSelecting) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Cancel selection',
            onPressed: () => setState(_selectedIds.clear),
            icon: const Icon(Icons.close_rounded),
            color: Colors.black54,
          ),
          IconButton(
            tooltip: 'Delete selected',
            onPressed: _deleteSelectedHistory,
            icon: const Icon(Icons.delete_rounded),
            color: Colors.red,
          ),
        ],
      );
    }

    // Header actions when not selecting:
    // - only show delete all (no select/check icon)
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Delete all',
          onPressed: _clearHistory,
          icon: const Icon(Icons.delete_outline_rounded),
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildDetectionTile(Map<String, dynamic> detection) {
    final id = detection['id']?.toString() ?? '';
    final isSelected = _selectedIds.contains(id);
    final imagePath = detection['image_path']?.toString() ?? '';
    final imageFile = File(imagePath);
    final confidence = (detection['confidence'] as num?)?.toDouble() ?? 0;
    final createdAt = DateTime.tryParse(
      detection['created_at']?.toString() ?? '',
    );

    // When selecting, we only want the checkbox/leading area to toggle selection.
    // This prevents accidental selection when tapping the thumbnail.
    void toggleSelection() => _toggleSelection(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF2E7D32)
              : Colors.grey.withValues(alpha: 0.12),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          if (_isSelecting)
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: toggleSelection,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? const Color(0xFF2E7D32) : Colors.black38,
                ),
              ),
            ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _isSelecting ? null : () => _openFullscreenImage(imageFile),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imagePath.isNotEmpty && imageFile.existsSync()
                  ? Image.file(
                      imageFile,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 72,
                      height: 72,
                      color: const Color(0xFFE8F5E9),
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detection['label']?.toString() ?? 'Unknown',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lifespan: ${detection['lifespan'] ?? 'N/A'}',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${confidence.toStringAsFixed(1)}% confidence',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                if (createdAt != null)
                  Text(
                    _formatDate(createdAt),
                    style: const TextStyle(color: Colors.black38, fontSize: 11),
                  ),

                // Delete button for every history item.
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      // If currently selected, remove from selection then delete.
                      if (_selectedIds.contains(id)) {
                        _selectedIds.remove(id);
                      }
                      setState(() {});

                      final confirmed = await _confirmDelete(
                        title: 'Delete this scan?',
                        message: 'This will permanently remove this scan.',
                        action: 'Delete',
                      );
                      if (!confirmed) return;
                      await DetectionHistoryStore.instance
                          .deleteDetectionsByIds({id});
                      await _reloadDetections();
                    },
                    icon: const Icon(Icons.delete_rounded, color: Colors.red),
                    label: const Text(
                      'Delete',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _detectionsFuture,
          builder: (context, snapshot) {
            final detections = (snapshot.data ?? []).where((detection) {
              final label = detection['label']?.toString().toLowerCase() ?? '';
              return !label.contains('invalid') &&
                  !label.contains('not a coconut') &&
                  !label.contains('not coconut');
            }).toList();

            return RefreshIndicator(
              onRefresh: _reloadDetections,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isSelecting
                            ? '${_selectedIds.length} selected'
                            : 'History',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      if (detections.isNotEmpty)
                        _buildHeaderActions(detections),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(child: CircularProgressIndicator())
                  else if (detections.isEmpty)
                    const Text(
                      'No scan history yet.',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    )
                  else
                    ...detections.map(_buildDetectionTile),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class FullscreenImagePage extends StatelessWidget {
  final File imageFile;

  const FullscreenImagePage({super.key, required this.imageFile});

  @override
  Widget build(BuildContext context) {
    final exists = imageFile.existsSync();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Image'),
        centerTitle: true,
      ),
      body: Center(
        child: exists
            ? InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.file(imageFile),
              )
            : const Text(
                'Image not found',
                style: TextStyle(color: Colors.white),
              ),
      ),
    );
  }
}
