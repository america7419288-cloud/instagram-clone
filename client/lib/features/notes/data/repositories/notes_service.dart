// lib/features/notes/data/repositories/notes_service.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../models/note_model.dart';

final notesServiceProvider = Provider<NotesService>((ref) {
  return NotesService(ref);
});

class NotesService {
  final Ref _ref;
  NotesService(this._ref);

  DioClient get _client => _ref.read(dioClientProvider);

  /// Fetch active notes feed for the logged-in user and their followed accounts
  Future<List<NoteModel>> getNotesFeed() async {
    final response = await _client.get(AppConstants.notesFeedUrl);
    if (response.data['success'] == true) {
      final List<dynamic> notesJson = response.data['data']['notes'] ?? [];
      return notesJson
          .map((n) => NoteModel.fromJson(n as Map<String, dynamic>))
          .toList();
    }
    throw Exception(response.data['message'] ?? 'Failed to load notes feed');
  }

  /// Create/Share a new note (replaces any existing note of the user)
  Future<NoteModel> createNote(
    String text,
    NoteAudience audience, {
    String? noteType,
    
    // Music
    String? musicTrackId,
    String? musicTrackName,
    String? musicArtistName,
    String? musicAlbumArt,
    String? musicPreviewUrl,
    int? musicDuration,
    String? musicPlatform,
    
    // GIF
    String? gifId,
    String? gifUrl,
    String? gifPreviewUrl,
    String? gifTitle,
    int? gifWidth,
    int? gifHeight,
    String? gifSource,
  }) async {
    final response = await _client.post(
      AppConstants.notesUrl,
      data: {
        'text': text,
        'audience': audience == NoteAudience.closeFriends ? 'close_friends' : 'followers',
        if (noteType != null) 'noteType': noteType,
        
        // Music
        if (musicTrackId != null) 'musicTrackId': musicTrackId,
        if (musicTrackName != null) 'musicTrackName': musicTrackName,
        if (musicArtistName != null) 'musicArtistName': musicArtistName,
        if (musicAlbumArt != null) 'musicAlbumArt': musicAlbumArt,
        if (musicPreviewUrl != null) 'musicPreviewUrl': musicPreviewUrl,
        if (musicDuration != null) 'musicDuration': musicDuration,
        if (musicPlatform != null) 'musicPlatform': musicPlatform,
        
        // GIF
        if (gifId != null) 'gifId': gifId,
        if (gifUrl != null) 'gifUrl': gifUrl,
        if (gifPreviewUrl != null) 'gifPreviewUrl': gifPreviewUrl,
        if (gifTitle != null) 'gifTitle': gifTitle,
        if (gifWidth != null) 'gifWidth': gifWidth,
        if (gifHeight != null) 'gifHeight': gifHeight,
        if (gifSource != null) 'gifSource': gifSource,
      },
    );
    if (response.data['success'] == true) {
      return NoteModel.fromJson(response.data['data'] as Map<String, dynamic>);
    }
    throw Exception(response.data['message'] ?? 'Failed to create note');
  }

  /// Delete the current user's active note
  Future<void> deleteNote() async {
    final response = await _client.delete(AppConstants.notesUrl);
    if (response.data['success'] != true) {
      throw Exception(response.data['message'] ?? 'Failed to delete note');
    }
  }
}
