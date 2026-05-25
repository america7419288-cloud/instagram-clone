// lib/features/inbox/pages/message_requests_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import 'package:flutter/services.dart';
import '../../../../core/router/app_router.dart';
import '../../chat/presentation/providers/chat_notifiers.dart';
import '../controllers/inbox_controller.dart';
import '../widgets/conversation_tile.dart';

class MessageRequestsPage extends ConsumerStatefulWidget {
  const MessageRequestsPage({super.key});

  @override
  ConsumerState<MessageRequestsPage> createState() => _MessageRequestsPageState();
}

class _MessageRequestsPageState extends ConsumerState<MessageRequestsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryController;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        _entryController.forward();
      }
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  void _openChat(String id, String username) {
    context.push(
      AppRoutes.chat.replaceAll(':conversationId', id),
      extra: {
        'username': username,
        'isVerified': false,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inboxState = ref.watch(inboxPageProvider);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0.5,
        scrolledUnderElevation: 1,
        title: Text(
          'Message requests',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFamily: 'SF Pro Display',
          ),
        ),
        leading: IconButton(
          icon: Icon(
            LucideIcons.chevron_left,
            color: isDark ? Colors.white : Colors.black,
            size: 28,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // Informative header text
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Decide who can message you',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                      fontFamily: 'SF Pro Display',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Open a request to see the message. The person who sent it won\'t know you\'ve seen it until you accept.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontFamily: 'SF Pro Text',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // Divider
          SliverToBoxAdapter(
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: isDark ? Colors.grey[850] : Colors.grey[300],
            ),
          ),

          // Requests list
          if (inboxState.requests.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.mail, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No Requests',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final conv = inboxState.requests[index];
                  return Column(
                    children: [
                      ConversationTile(
                        conversation: conv,
                        index: index,
                        entryController: _entryController,
                        onTap: () => _openChat(conv.id, conv.username),
                        onDelete: () => ref.read(inboxProvider.notifier).rejectRequest(conv.id),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 72, right: 16, bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  ref.read(inboxProvider.notifier).rejectRequest(conv.id);
                                },
                                child: Container(
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Decline',
                                    style: TextStyle(
                                      color: isDark ? Colors.red[400] : Colors.red[600],
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'SF Pro Text',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  HapticFeedback.mediumImpact();
                                  await ref.read(inboxProvider.notifier).acceptRequest(conv.id);
                                  // Refresh inbox and notes feed
                                  ref.read(inboxProvider.notifier).refresh();
                                },
                                child: Container(
                                  height: 32,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF3797EF),
                                        Color(0xFF007FFF),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'Accept',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'SF Pro Text',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: isDark ? Colors.grey[900] : Colors.grey[200],
                      ),
                    ],
                  );
                },
                childCount: inboxState.requests.length,
              ),
            ),
        ],
      ),
    );
  }
}
