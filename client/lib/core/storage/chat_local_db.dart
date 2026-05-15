import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../../features/chat/data/models/message.dart';
import '../../features/chat/data/models/conversation.dart';
import '../../features/chat/data/models/chat_user.dart';

class ChatLocalDb {
  static const String conversationBoxName = 'conversations';
  static const String messageBoxName = 'messages';

  Future<void> initialize() async {
    await Hive.initFlutter();
    
    // Register adapters if not already registered
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ChatUserAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(MessageAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(ConversationAdapter());

    await Hive.openBox<Conversation>(conversationBoxName);
    await Hive.openBox<Message>(messageBoxName);

    // Purge any poisoned entries with empty IDs (from prior failed API calls)
    await _purgeInvalidConversations();
  }

  Future<void> _purgeInvalidConversations() async {
    final box = _conversationBox;
    final invalidKeys = box.keys.where((k) => k.toString().isEmpty).toList();
    if (invalidKeys.isNotEmpty) {
      await box.deleteAll(invalidKeys);
    }
  }

  // Conversation operations
  Box<Conversation> get _conversationBox => Hive.box<Conversation>(conversationBoxName);
  
  List<Conversation> getConversations() {
    return _conversationBox.values
        .where((c) => c.id.isNotEmpty) // skip any corrupt entries
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Conversation? getConversation(String conversationId) {
    return _conversationBox.get(conversationId);
  }

  Future<void> saveConversation(Conversation conversation) async {
    await _conversationBox.put(conversation.id, conversation);
  }

  Future<void> saveConversations(List<Conversation> conversations) async {
    final Map<String, Conversation> conversationMap = {
      for (var conv in conversations) conv.id: conv
    };
    await _conversationBox.putAll(conversationMap);
  }

  // Message operations
  Box<Message> get _messageBox => Hive.box<Message>(messageBoxName);

  List<Message> getMessages(String conversationId) {
    return _messageBox.values
        .where((m) => m.conversationId == conversationId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Message? getMessage(String messageId) {
    return _messageBox.get(messageId);
  }

  Future<void> saveMessages(List<Message> messages) async {
    final Map<String, Message> messageMap = {
      for (var msg in messages) msg.id: msg
    };
    await _messageBox.putAll(messageMap);
  }

  Future<void> saveMessage(Message message) async {
    await _messageBox.put(message.id, message);
  }

  Future<void> deleteMessage(String messageId) async {
    await _messageBox.delete(messageId);
  }

  Future<void> clearAll() async {
    await _conversationBox.clear();
    await _messageBox.clear();
  }
}
