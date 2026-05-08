// lib/features/story/presentation/widgets/music_picker.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../providers/story_provider.dart';
import '../../data/repositories/story_service.dart';

class MusicPicker extends ConsumerStatefulWidget {
  const MusicPicker({super.key});

  @override
  ConsumerState<MusicPicker> createState() => _MusicPickerState();
}

class _MusicPickerState extends ConsumerState<MusicPicker> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  String _lastQuery = '';

  Future<void> _onSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _lastQuery = '';
      });
      return;
    }

    if (query == _lastQuery) return;

    setState(() {
      _isLoading = true;
      _lastQuery = query;
    });

    try {
      final results = await ref.read(storyServiceProvider).searchMusic(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CupertinoSearchTextField(
              controller: _searchController,
              placeholder: 'Search music...',
              onChanged: _onSearch,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
          ),
          const SizedBox(height: 16),

          // Results
          Expanded(
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'Browse for music'
                              : 'No results found',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final song = _results[index];
                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: song['thumbnail'] != null
                                  ? Image.network(
                                      song['thumbnail'],
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 48,
                                      height: 48,
                                      color: Colors.grey[300],
                                      child: const Icon(PhosphorIconsFill.musicNotes),
                                    ),
                            ),
                            title: Text(
                              song['title'] ?? 'Unknown',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              song['artist'] ?? 'Unknown Artist',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.grey),
                            ),
                            trailing: const Icon(PhosphorIconsFill.playCircle, color: Colors.grey),
                            onTap: () {
                              Navigator.pop(context, song);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
