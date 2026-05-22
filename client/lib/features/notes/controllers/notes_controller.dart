import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../chat/presentation/providers/chat_notifiers.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../models/note_model.dart';

import '../data/repositories/notes_service.dart';

class NotesState {
  final NoteModel? myNote;
  final List<NoteModel> friendNotes;

  const NotesState({
    this.myNote,
    this.friendNotes = const [],
  });

  NotesState copyWith({
    NoteModel? Function()? myNote,
    List<NoteModel>? friendNotes,
  }) {
    return NotesState(
      myNote: myNote != null ? myNote() : this.myNote,
      friendNotes: friendNotes ?? this.friendNotes,
    );
  }
}

class NotesNotifier extends Notifier<NotesState> {
  @override
  NotesState build() {
    // 1. Asynchronously load the persisted note and feed from SharedPreferences post-build
    Future.microtask(() async {
      await _loadPersistedNote();
      await fetchNotesFeed();
    });

    return const NotesState(
      myNote: null,
      friendNotes: [],
    );
  }

  /// Load persisted own note and friends feed from local storage for instant offline loading
  Future<void> _loadPersistedNote() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load own note
      final noteJsonStr = prefs.getString('user_own_note');
      NoteModel? loadedMyNote;
      if (noteJsonStr != null) {
        final decodedMap = jsonDecode(noteJsonStr) as Map<String, dynamic>;
        final note = NoteModel.fromJson(decodedMap);
        if (!note.isExpired) {
          loadedMyNote = note;
        } else {
          await prefs.remove('user_own_note');
        }
      }

      // Load friends notes
      final feedJsonStr = prefs.getString('friend_notes_feed');
      List<NoteModel> loadedFriendNotes = [];
      if (feedJsonStr != null) {
        final decodedList = jsonDecode(feedJsonStr) as List<dynamic>;
        loadedFriendNotes = decodedList
            .map((item) => NoteModel.fromJson(item as Map<String, dynamic>))
            .where((note) => !note.isExpired)
            .toList();
      }

      state = state.copyWith(
        myNote: () => loadedMyNote,
        friendNotes: loadedFriendNotes,
      );
    } catch (e) {
      // Suppress local storage loading errors
    }
  }

  /// Fetch the latest notes feed from the server
  Future<void> fetchNotesFeed() async {
    try {
      final service = ref.read(notesServiceProvider);
      final feed = await service.getNotesFeed();

      NoteModel? ownNote;
      final List<NoteModel> friendNotes = [];

      for (final note in feed) {
        if (note.isOwn) {
          ownNote = note;
        } else {
          friendNotes.add(note);
        }
      }

      state = state.copyWith(
        myNote: () => ownNote,
        friendNotes: friendNotes,
      );

      // Cache updated values locally
      final prefs = await SharedPreferences.getInstance();
      if (ownNote != null) {
        await prefs.setString('user_own_note', jsonEncode(ownNote.toJson()));
      } else {
        await prefs.remove('user_own_note');
      }

      final friendNotesJson = friendNotes.map((n) => n.toJson()).toList();
      await prefs.setString('friend_notes_feed', jsonEncode(friendNotesJson));
    } catch (e) {
      // Offline fallback: keep using current state
    }
  }

  /// Create and share a new note with followers or close friends
  Future<void> shareNote(String text, NoteAudience audience) async {
    try {
      final service = ref.read(notesServiceProvider);
      final note = await service.createNote(text, audience);

      state = state.copyWith(myNote: () => note);

      // Cache own note
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_own_note', jsonEncode(note.toJson()));
    } catch (e) {
      rethrow;
    }
  }

  /// Delete the user's active note
  Future<void> deleteNote() async {
    try {
      final service = ref.read(notesServiceProvider);
      await service.deleteNote();

      state = state.copyWith(myNote: () => null);

      // Remove from cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_own_note');
    } catch (e) {
      rethrow;
    }
  }

  /// Reply to a friend's active note via direct message
  Future<void> replyToNote(NoteModel note, String replyText) async {
    // 1. Resolve/create conversation with note author
    final chatNotifier = ref.read(inboxProvider.notifier);
    final inboxState = ref.read(inboxProvider);
    String conversationId = '';

    for (final c in inboxState.conversations) {
      if (c.otherUser?.username == note.username) {
        conversationId = c.id;
        break;
      }
    }

    if (conversationId.isEmpty) {
      // If conversation doesn't exist, create it dynamically
      try {
        final conversation = await chatNotifier.createConversation(note.userId);
        conversationId = conversation.id;
      } catch (e) {
        // Fallback to sending into first conversation or generic message
        if (inboxState.conversations.isNotEmpty) {
          conversationId = inboxState.conversations.first.id;
        } else {
          return; // Can't send if no conversation is resolvable
        }
      }
    }

    // 2. Format custom note-reply prefix
    final formattedMessage = '[note_reply]:${note.text}|$replyText';

    // 3. Trigger Riverpod sendMessage on ChatNotifier family
    final messageNotifier = ref.read(chatProvider(conversationId).notifier);
    await messageNotifier.sendMessage(formattedMessage);
  }
}

final notesProvider = NotifierProvider<NotesNotifier, NotesState>(NotesNotifier.new);
