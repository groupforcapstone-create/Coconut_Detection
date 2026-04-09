import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/history_notifier.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const _prefsKey = 'scan_history';
  List<String> _rawHistory = [];
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    historyUpdateNotifier.addListener(_loadHistory);
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];

    // Filter out invalid-image entries so they do not appear in history.
    final filtered =
        raw.map((e) => json.decode(e) as Map<String, dynamic>).where((item) {
      final label = (item['label'] ?? '').toString().toLowerCase();
      return label != 'invalid image';
    }).toList();

    setState(() {
      _rawHistory = raw;
      _history = filtered.reversed.toList();
    });
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    setState(() {
      _rawHistory = [];
      _history = [];
    });
  }

  Future<void> _removeHistoryItem(int displayIndex) async {
    final prefs = await SharedPreferences.getInstance();

    // We store raw JSON strings in _rawHistory; find the matching raw string
    // for the displayed entry and remove it.
    final item = _history[displayIndex];
    final itemJson = json.encode(item);

    final rawIndex = _rawHistory.indexOf(itemJson);
    if (rawIndex >= 0) {
      _rawHistory.removeAt(rawIndex);
      await prefs.setStringList(_prefsKey, _rawHistory);
    }

    setState(() {
      _history.removeAt(displayIndex);
    });
  }

  @override
  void dispose() {
    historyUpdateNotifier.removeListener(_loadHistory);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      body: Stack(
        children: [
          // Background accents
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF81C784).withValues(alpha: 0.15),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      const Text(
                        'Scan History',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B5E20)),
                      ),
                      const Spacer(),
                      if (_history.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.delete_forever),
                          color: const Color(0xFF1B5E20),
                          tooltip: 'Clear history',
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Clear history?'),
                                    content: const Text(
                                        'This will remove all saved scans.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF2E7D32)),
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Clear'),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;
                            if (confirmed) {
                              await _clearHistory();
                            }
                          },
                        )
                    ],
                  ),
                ),
                Expanded(
                  child: _history.isEmpty
                      ? const Center(
                          child: Text(
                            'No scans yet. Use the camera to save results here.',
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(fontSize: 16, color: Colors.black54),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          itemCount: _history.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = _history[index];
                            final label = item['label'] ?? 'Unknown';
                            final time = item['timestamp'] ?? '';
                            final imagePath = item['imagePath'] as String?;
                            final topPrediction =
                                (item['topPrediction'] ?? '').toString();
                            final address =
                                (item['address'] ?? '').toString();

                            return Dismissible(
                              key: ValueKey(time.toString() + label.toString()),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(Icons.delete,
                                    color: Colors.white),
                              ),
                              onDismissed: (_) => _removeHistoryItem(index),
                              child: _glassCard(
                                child: ListTile(
                                  leading: imagePath != null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Image.file(
                                            File(imagePath),
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                              Icons.photo,
                                              size: 40,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        )
                                      : const Icon(Icons.photo,
                                          color: Colors.grey),
                                  title: Text(label,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(time.toString(),
                                          style: const TextStyle(fontSize: 12)),
                                      if (address.isNotEmpty)
                                        Text(address,
                                            style:
                                                const TextStyle(fontSize: 12)),
                                      if (topPrediction.isNotEmpty)
                                        Text("Top: $topPrediction",
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF2E7D32),
                                                fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text(label),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (imagePath != null)
                                              Padding(
                                                padding:
                                                    const EdgeInsets.only(
                                                        bottom: 12),
                                                child: Image.file(
                                                  File(imagePath),
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      const SizedBox(),
                                                ),
                                              ),
                                            Text('Scanned at: $time'),
                                            const SizedBox(height: 8),
                                            Text(
                                                'Location: ${address.isEmpty ? 'Unknown' : address}'),
                                            const SizedBox(height: 8),
                                            Text(
                                                'Top prediction: $topPrediction'),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: const Text('Close')),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(ctx);
                                              _removeHistoryItem(index);
                                            },
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
