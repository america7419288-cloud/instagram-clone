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
  Future<NoteModel> createNote(String text, NoteAudience audience) async {
    final response = await _client.post(
      AppConstants.notesUrl,
      data: {
        'text': text,
        'audience': audience == NoteAudience.closeFriends ? 'close_friends' : 'followers',
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
