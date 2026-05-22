// lib/features/notes/controllers/notes_controller.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../chat/presentation/providers/chat_notifiers.dart';
import '../models/note_model.dart';

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

class NotesNotifier extends StateNotifier<NotesState> {
  final Ref _ref;

  NotesNotifier(this._ref) : super(const NotesState()) {
    _loadInitialNotes();
  }

  void _loadInitialNotes() {
    final now = DateTime.now();

    // Create high-fidelity mock notes with varying creation times to demonstrate decaying styling
    final mockNotes = [
      NoteModel(
        id: 'friend_1',
        userId: 'user_1',
        username: 'alex_mercer',
        avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&h=100&fit=crop',
        text: 'Coding late tonight... 💻☕',
        createdAt: now.subtract(const Duration(hours: 2)), // 2h ago -> Opacity 1.0, Solid border
        audience: NoteAudience.followers,
      ),
      NoteModel(
        id: 'friend_2',
        userId: 'user_2',
        username: 'sara.k',
        avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&h=100&fit=crop',
        text: '✈️ Heading to Paris! Au revoir!',
        createdAt: now.subtract(const Duration(hours: 14)), // 14h ago -> Opacity 0.85, Solid border
        audience: NoteAudience.closeFriends,
      ),
      NoteModel(
        id: 'friend_3',
        userId: 'user_3',
        username: 'john_doe',
        avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop',
        text: '🔥😂🙌', // Emoji only note
        createdAt: now.subtract(const Duration(hours: 5)), // 5h ago -> Opacity 0.85, Solid
        audience: NoteAudience.followers,
      ),
      NoteModel(
        id: 'friend_4',
        userId: 'user_4',
        username: 'emma_w',
        avatarUrl: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100&h=100&fit=crop',
        text: 'Any Netflix recommendations?',
        createdAt: now.subtract(const Duration(hours: 21)), // 21h ago -> Opacity 0.65, Dashed border!
        audience: NoteAudience.followers,
      ),
      NoteModel(
        id: 'friend_5',
        userId: 'user_5',
        username: 'marcus_fit',
        avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&h=100&fit=crop',
        text: 'Morning gym grind! 💪🎖️',
        createdAt: now.subtract(const Duration(minutes: 23 * 60 + 35)), // 23h 35m ago -> Opacity 0.4, Dashed, Expiring soon!
        audience: NoteAudience.closeFriends,
      ),
    ];

    state = NotesState(
      myNote: null, // Start with no own note
      friendNotes: mockNotes,
    );
  }

  void shareNote(String text, NoteAudience audience) {
    final note = NoteModel(
      id: 'my_note_id',
      userId: 'me',
      username: 'your_username',
      avatarUrl: '', // Will pull from auth
      text: text,
      createdAt: DateTime.now(),
      audience: audience,
      isOwn: true,
    );

    state = state.copyWith(myNote: () => note);
  }

  void deleteNote() {
    state = state.copyWith(myNote: () => null);
  }

  Future<void> replyToNote(NoteModel note, String replyText) async {
    // 1. Resolve/create conversation with note author
    final chatNotifier = _ref.read(inboxProvider.notifier);
    
    // For demo/routing purposes, in a real app this uses note.userId
    // If it's a mock note user (friend_1, etc.), we map them or create a local mock DM channel
    // Let's lookup if there is already an existing conversation with note.username.
    final inboxState = _ref.read(inboxProvider);
    String conversationId = '';
    
    for (final c in inboxState.conversations) {
      if (c.otherUser?.username == note.username) {
        conversationId = c.id;
        break;
      }
    }

    if (conversationId.isEmpty) {
      // If conversation doesn't exist, create it dynamically
      final resolvedUser = note.userId.startsWith('friend_') ? 'friend_user_id' : note.userId;
      try {
        final conversation = await chatNotifier.createConversation(resolvedUser);
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
    final messageNotifier = _ref.read(chatProvider(conversationId).notifier);
    await messageNotifier.sendMessage(formattedMessage);
  }
}

final notesProvider = StateNotifierProvider<NotesNotifier, NotesState>((ref) {
  return NotesNotifier(ref);
});
