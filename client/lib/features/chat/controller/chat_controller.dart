import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/message.dart';

class ChatController extends ChangeNotifier {
  final String conversationId;

  ChatController({required this.conversationId});

  // ── State ──────────────────────────────────

  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isTyping = false;       // other person typing
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  Timer? _typingTimer;

  // Input
  String _inputText = '';
  ChatMessage? _replyingTo;

  // Scroll
  final scrollController = ScrollController();

  // ── Getters ────────────────────────────────

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isTyping => _isTyping;
  bool get isRecording => _isRecording;
  Duration get recordingDuration => _recordingDuration;
  String get inputText => _inputText;
  ChatMessage? get replyingTo => _replyingTo;
  bool get hasText => _inputText.trim().isNotEmpty;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(
        const Duration(milliseconds: 600));

    _messages = ChatMessage.mockMessages();
    _isLoading = false;
    notifyListeners();

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animate: false);
    });

    // Simulate incoming messages
    _simulateTyping();
  }

  void onTextChanged(String text) {
    _inputText = text;
    notifyListeners();
  }

  // ── Reply ──────────────────────────────────

  void setReply(ChatMessage message) {
    _replyingTo = message;
    notifyListeners();
  }

  void clearReply() {
    _replyingTo = null;
    notifyListeners();
  }

  // ── Send Messages ──────────────────────────

  Future<void> sendText(String text) async {
    if (text.trim().isEmpty) return;

    final replyMsg = _replyingTo;
    _replyingTo = null;
    notifyListeners();

    ReplyData? replyData;
    if (replyMsg != null) {
      replyData = ReplyData(
        messageId: replyMsg.id,
        senderId: replyMsg.senderId,
        senderName: replyMsg.senderName,
        previewText: replyMsg.previewText,
        previewImage: replyMsg.thumbnailUrl,
        originalType: replyMsg.type,
      );
    }

    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch
          .toString(),
      conversationId: conversationId,
      senderId: 'me',
      senderName: 'me',
      type: MessageType.text,
      text: text.trim(),
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      isFromMe: true,
      replyTo: replyData,
    );

    _messages.add(msg);
    notifyListeners();
    _scrollToBottom();
    HapticFeedback.lightImpact();

    // Simulate API
    await Future.delayed(
        const Duration(milliseconds: 500));
    _updateStatus(msg.id, MessageStatus.sent);

    await Future.delayed(const Duration(seconds: 1));
    _updateStatus(msg.id, MessageStatus.delivered);
  }

  Future<void> sendImage(String url) async {
    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch
          .toString(),
      conversationId: conversationId,
      senderId: 'me',
      senderName: 'me',
      type: MessageType.image,
      mediaUrl: url,
      thumbnailUrl: url,
      aspectRatio: 4 / 5,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      isFromMe: true,
    );

    _messages.add(msg);
    notifyListeners();
    _scrollToBottom();
    HapticFeedback.lightImpact();

    await Future.delayed(
        const Duration(milliseconds: 800));
    _updateStatus(msg.id, MessageStatus.delivered);
  }

  // ── Audio Recording ────────────────────────

  void startRecording() {
    _isRecording = true;
    _recordingDuration = Duration.zero;
    notifyListeners();
    HapticFeedback.mediumImpact();

    _recordingTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        _recordingDuration +=
            const Duration(seconds: 1);
        notifyListeners();
      },
    );
  }

  Future<void> stopRecording() async {
    _recordingTimer?.cancel();
    final duration = _recordingDuration;
    _isRecording = false;
    _recordingDuration = Duration.zero;
    notifyListeners();

    if (duration.inSeconds < 1) return;

    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch
          .toString(),
      conversationId: conversationId,
      senderId: 'me',
      senderName: 'me',
      type: MessageType.audio,
      audioData: AudioData.mock(duration),
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
      isFromMe: true,
    );

    _messages.add(msg);
    notifyListeners();
    _scrollToBottom();
    HapticFeedback.lightImpact();
  }

  void cancelRecording() {
    _recordingTimer?.cancel();
    _isRecording = false;
    _recordingDuration = Duration.zero;
    notifyListeners();
    HapticFeedback.heavyImpact();
  }

  // ── Reactions ──────────────────────────────

  void react(String messageId, String emoji) {
    final idx = _messages.indexWhere(
        (m) => m.id == messageId);
    if (idx == -1) return;

    final reactions = List<MessageReaction>.from(
        _messages[idx].reactions);

    // Toggle: remove if already reacted with same
    final existing = reactions.indexWhere(
        (r) => r.userId == 'me' && r.emoji == emoji);

    if (existing != -1) {
      reactions.removeAt(existing);
    } else {
      reactions.removeWhere((r) => r.userId == 'me');
      reactions.add(MessageReaction(
        userId: 'me',
        username: 'me',
        emoji: emoji,
        at: DateTime.now(),
      ));
    }

    _messages[idx] = _messages[idx]
        .copyWith(reactions: reactions);
    notifyListeners();
    HapticFeedback.lightImpact();
  }

  // ── Unsend / Delete ────────────────────────

  void unsend(String messageId) {
    final idx = _messages.indexWhere(
        (m) => m.id == messageId);
    if (idx == -1) return;
    _messages[idx] = _messages[idx]
        .copyWith(isDeleted: true);
    notifyListeners();
  }

  void deleteForMe(String messageId) {
    _messages.removeWhere((m) => m.id == messageId);
    notifyListeners();
  }

  // ── Helpers ────────────────────────────────

  void _updateStatus(
      String id, MessageStatus status) {
    final idx = _messages.indexWhere(
        (m) => m.id == id);
    if (idx == -1) return;
    _messages[idx] =
        _messages[idx].copyWith(status: status);
    notifyListeners();
  }

  void _scrollToBottom({bool animate = true}) {
    if (!scrollController.hasClients) return;
    final target =
        scrollController.position.maxScrollExtent;
    if (animate) {
      scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      scrollController.jumpTo(target);
    }
  }

  // Simulate other person typing
  void _simulateTyping() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!hasListeners) return;
      _isTyping = true;
      notifyListeners();

      Future.delayed(const Duration(seconds: 2), () {
        if (!hasListeners) return;
        _isTyping = false;

        // Send a reply
        final reply = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch
              .toString(),
          conversationId: conversationId,
          senderId: 'other',
          senderName: 'johndoe',
          senderAvatar:
              'https://i.pravatar.cc/150?img=1',
          type: MessageType.text,
          text: 'Can\'t wait to see the final result!',
          timestamp: DateTime.now(),
          status: MessageStatus.delivered,
          isFromMe: false,
        );

        _messages.add(reply);
        notifyListeners();
        _scrollToBottom();
        HapticFeedback.lightImpact();
      });
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _typingTimer?.cancel();
    scrollController.dispose();
    super.dispose();
  }
}
