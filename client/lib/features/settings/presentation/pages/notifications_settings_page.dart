import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../providers/settings_provider.dart';

class NotificationsSettingsPage extends ConsumerWidget {
  const NotificationsSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(userSettingsProvider);
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : const Color(0xFFF2F2F7);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: settingsState.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        data: (settings) {
          final isPaused = settings.notifications.pauseAll;
          final pauseUntilStr = settings.notifications.pauseUntil;
          bool isPauseActive = false;
          if (isPaused && pauseUntilStr != null) {
            final pauseUntil = DateTime.tryParse(pauseUntilStr);
            if (pauseUntil != null && pauseUntil.isAfter(DateTime.now())) {
              isPauseActive = true;
            }
          }

          return ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              _buildSectionHeader('Push Notifications'),
              CupertinoListSection.insetGrouped(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                backgroundColor: Colors.transparent,
                children: [
                  CupertinoListTile(
                    leading: const Icon(LucideIcons.bell),
                    title: const Text('Enable Push Notifications', style: TextStyle(fontSize: 15)),
                    trailing: CupertinoSwitch(
                      value: settings.notifications.pushEnabled,
                      onChanged: (val) {
                        ref.read(userSettingsProvider.notifier).updateNotifications(pushEnabled: val);
                      },
                    ),
                  ),
                  CupertinoListTile(
                    leading: const Icon(LucideIcons.bell_off),
                    title: const Text('Pause All', style: TextStyle(fontSize: 15)),
                    subtitle: isPauseActive
                        ? Text('Paused until ${DateTime.parse(pauseUntilStr!).toLocal().toString().substring(0, 16)}', style: const TextStyle(fontSize: 11, color: Colors.grey))
                        : const Text('Temporarily pause notifications.', style: TextStyle(fontSize: 12)),
                    trailing: CupertinoSwitch(
                      value: isPauseActive,
                      onChanged: (val) {
                        if (val) {
                          _showPauseDurationPicker(context, ref);
                        } else {
                          ref.read(userSettingsProvider.notifier).updateNotifications(
                            pauseAll: false,
                            pauseUntil: '',
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),

              _buildSectionHeader('Interactions'),
              CupertinoListSection.insetGrouped(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                backgroundColor: Colors.transparent,
                children: [
                  CupertinoListTile(
                    leading: const Icon(LucideIcons.heart),
                    title: const Text('Likes', style: TextStyle(fontSize: 15)),
                    trailing: Text(settings.notifications.likes.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    onTap: () => _showPicker(
                      context,
                      'Likes Notifications',
                      ['off', 'from_following', 'everyone'],
                      settings.notifications.likes,
                      (val) {
                        ref.read(userSettingsProvider.notifier).updateNotifications(likes: val);
                      },
                    ),
                  ),
                  CupertinoListTile(
                    leading: const Icon(LucideIcons.message_square),
                    title: const Text('Comments', style: TextStyle(fontSize: 15)),
                    trailing: Text(settings.notifications.comments.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    onTap: () => _showPicker(
                      context,
                      'Comments Notifications',
                      ['off', 'from_following', 'everyone'],
                      settings.notifications.comments,
                      (val) {
                        ref.read(userSettingsProvider.notifier).updateNotifications(comments: val);
                      },
                    ),
                  ),
                  CupertinoListTile(
                    leading: const Icon(LucideIcons.at_sign),
                    title: const Text('Mentions', style: TextStyle(fontSize: 15)),
                    trailing: Text(settings.notifications.mentions.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    onTap: () => _showPicker(
                      context,
                      'Mentions Notifications',
                      ['off', 'from_following', 'everyone'],
                      settings.notifications.mentions,
                      (val) {
                        ref.read(userSettingsProvider.notifier).updateNotifications(mentions: val);
                      },
                    ),
                  ),
                  CupertinoListTile(
                    leading: const Icon(LucideIcons.heart_handshake),
                    title: const Text('Comment Likes', style: TextStyle(fontSize: 15)),
                    trailing: CupertinoSwitch(
                      value: settings.notifications.commentLikes,
                      onChanged: (val) {
                        ref.read(userSettingsProvider.notifier).updateNotifications(commentLikes: val);
                      },
                    ),
                  ),
                ],
              ),

              _buildSectionHeader('Followers and Messages'),
              CupertinoListSection.insetGrouped(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                backgroundColor: Colors.transparent,
                children: [
                  CupertinoListTile(
                    leading: const Icon(LucideIcons.user_plus),
                    title: const Text('New Followers', style: TextStyle(fontSize: 15)),
                    trailing: CupertinoSwitch(
                      value: settings.notifications.newFollowers,
                      onChanged: (val) {
                        ref.read(userSettingsProvider.notifier).updateNotifications(newFollowers: val);
                      },
                    ),
                  ),
                  CupertinoListTile(
                    leading: const Icon(LucideIcons.user_check),
                    title: const Text('Accepted Follow Requests', style: TextStyle(fontSize: 15)),
                    trailing: CupertinoSwitch(
                      value: settings.notifications.acceptedFollowRequests,
                      onChanged: (val) {
                        ref.read(userSettingsProvider.notifier).updateNotifications(acceptedFollowRequests: val);
                      },
                    ),
                  ),
                  CupertinoListTile(
                    leading: const Icon(LucideIcons.send),
                    title: const Text('Direct Messages', style: TextStyle(fontSize: 15)),
                    trailing: CupertinoSwitch(
                      value: settings.notifications.directMessages,
                      onChanged: (val) {
                        ref.read(userSettingsProvider.notifier).updateNotifications(directMessages: val);
                      },
                    ),
                  ),
                ],
              ),

              _buildSectionHeader('Stories and Broadcasts'),
              CupertinoListSection.insetGrouped(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                backgroundColor: Colors.transparent,
                children: [
                  CupertinoListTile(
                    leading: const Icon(LucideIcons.tv),
                    title: const Text('Live Videos', style: TextStyle(fontSize: 15)),
                    trailing: CupertinoSwitch(
                      value: settings.notifications.liveVideos,
                      onChanged: (val) {
                        ref.read(userSettingsProvider.notifier).updateNotifications(liveVideos: val);
                      },
                    ),
                  ),
                  CupertinoListTile(
                    leading: const Icon(LucideIcons.circle_play),
                    title: const Text('Stories', style: TextStyle(fontSize: 15)),
                    trailing: CupertinoSwitch(
                      value: settings.notifications.stories,
                      onChanged: (val) {
                        ref.read(userSettingsProvider.notifier).updateNotifications(stories: val);
                      },
                    ),
                  ),
                ],
              ),

              _buildSectionHeader('Other Channels'),
              CupertinoListSection.insetGrouped(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                backgroundColor: Colors.transparent,
                children: [
                  CupertinoListTile(
                    leading: const Icon(LucideIcons.mail),
                    title: const Text('Email Notifications', style: TextStyle(fontSize: 15)),
                    trailing: CupertinoSwitch(
                      value: settings.notifications.emailNotifications,
                      onChanged: (val) {
                        ref.read(userSettingsProvider.notifier).updateNotifications(emailNotifications: val);
                      },
                    ),
                  ),
                  CupertinoListTile(
                    leading: const Icon(LucideIcons.message_square),
                    title: const Text('SMS Notifications', style: TextStyle(fontSize: 15)),
                    trailing: CupertinoSwitch(
                      value: settings.notifications.smsNotifications,
                      onChanged: (val) {
                        ref.read(userSettingsProvider.notifier).updateNotifications(smsNotifications: val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF8E8E8E),
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.1,
        ),
      ),
    );
  }

  void _showPauseDurationPicker(BuildContext context, WidgetRef ref) {
    final durations = [
      {'label': '15 Minutes', 'duration': const Duration(minutes: 15)},
      {'label': '1 Hour', 'duration': const Duration(hours: 1)},
      {'label': '2 Hours', 'duration': const Duration(hours: 2)},
      {'label': '4 Hours', 'duration': const Duration(hours: 4)},
      {'label': '8 Hours', 'duration': const Duration(hours: 8)},
    ];

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Pause All Notifications'),
        actions: durations.map((d) {
          return CupertinoActionSheetAction(
            onPressed: () {
              final until = DateTime.now().add(d['duration'] as Duration).toUtc().toIso8601String();
              ref.read(userSettingsProvider.notifier).updateNotifications(
                pauseAll: true,
                pauseUntil: until,
              );
              Navigator.pop(context);
            },
            child: Text(d['label'] as String),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDestructiveAction: true,
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showPicker(BuildContext context, String title, List<String> options, String current, ValueChanged<String> onSelected) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(title),
        actions: options.map((opt) {
          final isSelected = opt == current;
          return CupertinoActionSheetAction(
            onPressed: () {
              onSelected(opt);
              Navigator.pop(context);
            },
            child: Text(
              opt.replaceAll('_', ' ').toUpperCase(),
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF0095F6) : null,
              ),
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDestructiveAction: true,
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
