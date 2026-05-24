import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/models/community.dart';
import '../../data/models/community_channel.dart';
import '../../data/models/community_post.dart';
import '../../data/models/community_rule.dart';
import '../../data/repositories/community_repository.dart';
import '../../../../core/socket/socket_service.dart';

// ─── 1. REPOSITORY PROVIDER ─────────────────────────────────
final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  final dio = ref.watch(dioClientProvider).dio;
  return CommunityRepository(dio);
});

// ─── 2. MY JOINED COMMUNITIES PROVIDER ───────────────────────
class MyCommunitiesNotifier extends AsyncNotifier<List<Community>> {
  @override
  Future<List<Community>> build() async {
    return ref.watch(communityRepositoryProvider).getMyCommunities();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(communityRepositoryProvider).getMyCommunities());
  }

  Future<Community> create({
    required String name,
    required String handle,
    String? description,
    String? category,
    String? privacy,
    List<String>? tags,
  }) async {
    final community = await ref.read(communityRepositoryProvider).createCommunity(
      name: name,
      handle: handle,
      description: description,
      category: category,
      privacy: privacy,
      tags: tags,
    );
    await refresh();
    return community;
  }

  Future<void> leave(String communityId) async {
    await ref.read(communityRepositoryProvider).leaveCommunity(communityId);
    await refresh();
  }

  Future<String> joinViaInvite(String inviteCode) async {
    final communityId = await ref.read(communityRepositoryProvider).joinViaInviteLink(inviteCode);
    await refresh();
    return communityId;
  }
}

final myCommunitiesProvider = AsyncNotifierProvider<MyCommunitiesNotifier, List<Community>>(() {
  return MyCommunitiesNotifier();
});

// ─── 3. DISCOVER COMMUNITIES PROVIDER ───────────────────────
final discoverCommunitiesProvider = FutureProvider.family<List<Community>, String?>((ref, category) async {
  return ref.watch(communityRepositoryProvider).discoverCommunities(category: category);
});

// ─── 4. SEARCH COMMUNITIES PROVIDER ─────────────────────────
final searchCommunitiesProvider = FutureProvider.family<List<Community>, String>((ref, query) async {
  if (query.trim().length < 2) return const [];
  return ref.watch(communityRepositoryProvider).searchCommunities(query: query);
});

// ─── 5. COMMUNITY DETAILS STATE PROVIDER ────────────────────
class CommunityDetailsNotifier extends Notifier<AsyncValue<Map<String, dynamic>>> {
  late String communityId;

  @override
  AsyncValue<Map<String, dynamic>> build() {
    Future.microtask(() => fetch());
    return const AsyncValue.loading();
  }

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(communityRepositoryProvider).getCommunityDetails(communityId));
  }

  Future<void> join({String? message}) async {
    await ref.read(communityRepositoryProvider).joinCommunity(communityId, message: message);
    await fetch();
  }
}

final communityDetailsProvider = NotifierProvider.family<CommunityDetailsNotifier, AsyncValue<Map<String, dynamic>>, String>(
  (id) => CommunityDetailsNotifier()..communityId = id,
);

// ─── 6. CHANNELS LIST PROVIDER ──────────────────────────────
final channelsProvider = FutureProvider.family<List<CommunityChannel>, String>((ref, communityId) async {
  return ref.watch(communityRepositoryProvider).getChannels(communityId);
});

// ─── 7. COMMUNITY RULES PROVIDER ────────────────────────────
final rulesProvider = FutureProvider.family<List<CommunityRule>, String>((ref, communityId) async {
  return ref.watch(communityRepositoryProvider).getRules(communityId);
});

// ─── 8. FEED POSTS NOTIFIER & PROVIDER ──────────────────────
class CommunityFeedParams {
  final String communityId;
  final String channelId;

  CommunityFeedParams({required this.communityId, required this.channelId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommunityFeedParams &&
          runtimeType == other.runtimeType &&
          communityId == other.communityId &&
          channelId == other.channelId;

  @override
  int get hashCode => communityId.hashCode ^ channelId.hashCode;
}

class CommunityFeedNotifier extends Notifier<AsyncValue<List<CommunityPost>>> {
  late CommunityFeedParams params;

  @override
  AsyncValue<List<CommunityPost>> build() {
    // Join socket room
    SocketService().joinCommunity(params.communityId);

    // Listen to real-time events
    final sub = SocketService().communityStream.listen((eventData) {
      final event = eventData['event'];
      final data = eventData['data'] as Map<String, dynamic>;

      if (event == 'new-post') {
        final post = CommunityPost.fromJson(data);
        if (post.channelId == params.channelId) {
          state.whenData((posts) {
            // Avoid duplicates
            if (!posts.any((p) => p.id == post.id)) {
              state = AsyncValue.data([post, ...posts]);
            }
          });
        }
      } else if (event == 'poll-updated') {
        final postId = data['post_id'] as String;
        final poll = data['poll'] as Map<String, dynamic>;
        state.whenData((posts) {
          state = AsyncValue.data(posts.map((p) {
            if (p.id == postId) {
              return CommunityPost(
                id: p.id,
                communityId: p.communityId,
                channelId: p.channelId,
                authorId: p.authorId,
                content: p.content,
                mediaUrls: p.mediaUrls,
                type: p.type,
                poll: poll,
                event: p.event,
                likes: p.likes,
                commentCount: p.commentCount,
                likeCount: p.likeCount,
                isPinned: p.isPinned,
                isAnnouncement: p.isAnnouncement,
                status: p.status,
                author: p.author,
                createdAt: p.createdAt,
              );
            }
            return p;
          }).toList());
        });
      } else if (event == 'event-updated') {
        final postId = data['post_id'] as String;
        final eventVal = data['event'] as Map<String, dynamic>;
        state.whenData((posts) {
          state = AsyncValue.data(posts.map((p) {
            if (p.id == postId) {
              return CommunityPost(
                id: p.id,
                communityId: p.communityId,
                channelId: p.channelId,
                authorId: p.authorId,
                content: p.content,
                mediaUrls: p.mediaUrls,
                type: p.type,
                poll: p.poll,
                event: eventVal,
                likes: p.likes,
                commentCount: p.commentCount,
                likeCount: p.likeCount,
                isPinned: p.isPinned,
                isAnnouncement: p.isAnnouncement,
                status: p.status,
                author: p.author,
                createdAt: p.createdAt,
              );
            }
            return p;
          }).toList());
        });
      }
    });

    ref.onDispose(() {
      sub.cancel();
    });

    Future.microtask(() => fetch());
    return const AsyncValue.loading();
  }

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(communityRepositoryProvider).getCommunityPosts(
      params.communityId,
      channelId: params.channelId,
    ));
  }

  Future<void> addPost({
    String? content,
    String type = 'text',
    Map<String, dynamic>? poll,
    Map<String, dynamic>? event,
    List<String>? mediaPaths,
  }) async {
    final newPost = await ref.read(communityRepositoryProvider).createPost(
      params.communityId,
      channelId: params.channelId,
      content: content,
      type: type,
      poll: poll,
      event: event,
      mediaPaths: mediaPaths,
    );
    
    state.whenData((posts) {
      state = AsyncValue.data([newPost, ...posts]);
    });
  }

  Future<void> delete(String postId) async {
    await ref.read(communityRepositoryProvider).deletePost(params.communityId, postId);
    state.whenData((posts) {
      state = AsyncValue.data(posts.where((p) => p.id != postId).toList());
    });
  }

  Future<void> toggleLike(String postId, String currentUserId) async {
    state.whenData((posts) {
      final updated = posts.map((p) {
        if (p.id == postId) {
          final isLiked = p.likes.contains(currentUserId);
          final newLikes = List<String>.from(p.likes);
          if (isLiked) {
            newLikes.remove(currentUserId);
          } else {
            newLikes.add(currentUserId);
          }
          return CommunityPost(
            id: p.id,
            communityId: p.communityId,
            channelId: p.channelId,
            authorId: p.authorId,
            content: p.content,
            mediaUrls: p.mediaUrls,
            type: p.type,
            poll: p.poll,
            event: p.event,
            likes: newLikes,
            commentCount: p.commentCount,
            likeCount: newLikes.length,
            isPinned: p.isPinned,
            isAnnouncement: p.isAnnouncement,
            status: p.status,
            author: p.author,
            createdAt: p.createdAt,
          );
        }
        return p;
      }).toList();
      state = AsyncValue.data(updated);
    });

    try {
      await ref.read(communityRepositoryProvider).likePost(params.communityId, postId);
    } catch (e) {
      fetch();
    }
  }

  Future<void> togglePin(String postId) async {
    state.whenData((posts) {
      final updated = posts.map((p) {
        if (p.id == postId) {
          return CommunityPost(
            id: p.id,
            communityId: p.communityId,
            channelId: p.channelId,
            authorId: p.authorId,
            content: p.content,
            mediaUrls: p.mediaUrls,
            type: p.type,
            poll: p.poll,
            event: p.event,
            likes: p.likes,
            commentCount: p.commentCount,
            likeCount: p.likeCount,
            isPinned: !p.isPinned,
            isAnnouncement: p.isAnnouncement,
            status: p.status,
            author: p.author,
            createdAt: p.createdAt,
          );
        }
        return p;
      }).toList();
      state = AsyncValue.data(updated);
    });

    try {
      await ref.read(communityRepositoryProvider).pinPost(params.communityId, postId, pin: true);
    } catch (e) {
      fetch();
    }
  }

  Future<void> vote(String postId, int optionIndex, String currentUserId) async {
    state.whenData((posts) {
      final updated = posts.map((p) {
        if (p.id == postId && p.type == 'poll' && p.poll != null) {
          final pollData = Map<String, dynamic>.from(p.poll!);
          final options = List<Map<String, dynamic>>.from(
            (pollData['options'] as List).map((x) => Map<String, dynamic>.from(x))
          );

          for (final opt in options) {
            final votes = List<String>.from(opt['votes'] ?? []);
            votes.remove(currentUserId);
            opt['votes'] = votes;
          }

          final votes = List<String>.from(options[optionIndex]['votes'] ?? []);
          if (!votes.contains(currentUserId)) {
            votes.add(currentUserId);
          }
          options[optionIndex]['votes'] = votes;
          pollData['options'] = options;

          return CommunityPost(
            id: p.id,
            communityId: p.communityId,
            channelId: p.channelId,
            authorId: p.authorId,
            content: p.content,
            mediaUrls: p.mediaUrls,
            type: p.type,
            poll: pollData,
            event: p.event,
            likes: p.likes,
            commentCount: p.commentCount,
            likeCount: p.likeCount,
            isPinned: p.isPinned,
            isAnnouncement: p.isAnnouncement,
            status: p.status,
            author: p.author,
            createdAt: p.createdAt,
          );
        }
        return p;
      }).toList();
      state = AsyncValue.data(updated);
    });

    try {
      final result = await ref.read(communityRepositoryProvider).votePoll(params.communityId, postId, optionIndex);
      state.whenData((posts) {
        state = AsyncValue.data(posts.map((p) {
          if (p.id == postId) {
            return CommunityPost(
              id: p.id,
              communityId: p.communityId,
              channelId: p.channelId,
              authorId: p.authorId,
              content: p.content,
              mediaUrls: p.mediaUrls,
              type: p.type,
              poll: result['poll'],
              event: p.event,
              likes: p.likes,
              commentCount: p.commentCount,
              likeCount: p.likeCount,
              isPinned: p.isPinned,
              isAnnouncement: p.isAnnouncement,
              status: p.status,
              author: p.author,
              createdAt: p.createdAt,
            );
          }
          return p;
        }).toList());
      });
    } catch (e) {
      fetch();
    }
  }

  Future<void> rsvp(String postId, String currentUserId) async {
    state.whenData((posts) {
      final updated = posts.map((p) {
        if (p.id == postId && p.type == 'event' && p.event != null) {
          final eventData = Map<String, dynamic>.from(p.event!);
          final attendees = List<String>.from(eventData['attendees'] ?? []);
          if (attendees.contains(currentUserId)) {
            attendees.remove(currentUserId);
          } else {
            attendees.add(currentUserId);
          }
          eventData['attendees'] = attendees;

          return CommunityPost(
            id: p.id,
            communityId: p.communityId,
            channelId: p.channelId,
            authorId: p.authorId,
            content: p.content,
            mediaUrls: p.mediaUrls,
            type: p.type,
            poll: p.poll,
            event: eventData,
            likes: p.likes,
            commentCount: p.commentCount,
            likeCount: p.likeCount,
            isPinned: p.isPinned,
            isAnnouncement: p.isAnnouncement,
            status: p.status,
            author: p.author,
            createdAt: p.createdAt,
          );
        }
        return p;
      }).toList();
      state = AsyncValue.data(updated);
    });

    try {
      final result = await ref.read(communityRepositoryProvider).rsvpEvent(params.communityId, postId);
      state.whenData((posts) {
        state = AsyncValue.data(posts.map((p) {
          if (p.id == postId) {
            return CommunityPost(
              id: p.id,
              communityId: p.communityId,
              channelId: p.channelId,
              authorId: p.authorId,
              content: p.content,
              mediaUrls: p.mediaUrls,
              type: p.type,
              poll: p.poll,
              event: result['event'],
              likes: p.likes,
              commentCount: p.commentCount,
              likeCount: p.likeCount,
              isPinned: p.isPinned,
              isAnnouncement: p.isAnnouncement,
              status: p.status,
              author: p.author,
              createdAt: p.createdAt,
            );
          }
          return p;
        }).toList());
      });
    } catch (e) {
      fetch();
    }
  }
}

final communityFeedProvider = NotifierProvider.family<CommunityFeedNotifier, AsyncValue<List<CommunityPost>>, CommunityFeedParams>(
  (params) => CommunityFeedNotifier()..params = params,
);
