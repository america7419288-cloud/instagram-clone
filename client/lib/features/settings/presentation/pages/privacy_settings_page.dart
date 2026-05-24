import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../providers/settings_provider.dart';

class PrivacySettingsPage extends ConsumerStatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  ConsumerState<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends ConsumerState<PrivacySettingsPage> {
  final _wordController = TextEditingController();

  @override
  void dispose() {
    _wordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(userSettingsProvider);
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : const Color(0xFFF2F2F7);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Privacy settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: settingsState.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        data: (settings) {
          _wordController.text = settings.comments.filteredWords.join(', ');

          return ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              // ─── ACCOUNT PRIVACY ──────────────────────────────
              _buildSectionHeader('Account Privacy'),
              CupertinoListSection.insetGrouped(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                backgroundColor: Colors.transparent,
                children: [
                  CupertinoListTile(
                    leading: const Icon(LucideIcons.lock),
                    title: const Text('Private Account', style: TextStyle(fontSize: 15)),
                    subtitle: const Text('Only people you approve can see your photos and videos.', style: TextStyle(fontSize: 12)),
                    trailing: CupertinoSwitch(
                      value: settings.privacy.isPrivateAccount,
                      onChanged: (val) {
                        ref.read(userSettingsProvider.notifier).updatePrivacy(isPrivateAccount: val);
                      },
                    ),
                  ),
                  CupertinoListTile(
                    leading: const Icon(LucideIcons.activity),
                    title: const Text('Show Activity Status', style: TextStyle(fontSize: 15)),
                    subtitle: const Text('Allow accounts you follow to see when you were last active.', style: TextStyle(fontSize: 12)),
                    trailing: CupertinoSwitch(
                      value: settings.privacy.showActivityStatus,
                      onChanged: (val) {
                        ref.read(userSettingsProvider.notifier).updatePrivacy(showActivityStatus: val);
                      },
                    ),
                  ),
                ],
              ),

              // ─── COMMENTS ─────────────────────────────────────
              _buildSectionHeader('Comments Settings'),
              CupertinoListSection.insetGrouped(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                backgroundColor: Colors.transparent,
                children: [
                  CupertinoListTile(
                    leading: const Icon(LucideIcons.message_square),
                    title: const Text('Allow Comments From', style: TextStyle(fontSize: 15)),
                    trailing: Text(settings.comments.allowComments.toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    onTap: () => _showPicker(
                      context,
                      'Allow Comments From',
                      ['everyone', 'following', 'followers', 'off'],
                      settings.comments.allowComments,
                      (val) {
                        ref.read(userSettingsProvider.notifier).updateComments(allowComments: val);
                      },
                    ),
                  ),
                  CupertinoListTile(
                    leading: const Icon(LucideIcons.shield_alert),
                    title: const Text('Hide Offensive Comments', style: TextStyle(fontSize: 15)),
                    subtitle: const Text('Automatically hide comments that may be offensive.', style: TextStyle(fontSize: 12)),
                    trailing: CupertinoSwitch(
                      value: settings.comments.filterOffensiveComments,
                      onChanged: (val) {
                        ref.read(userSettingsProvider.notifier).updateComments(filterOffensiveComments: val);
                      },
                    ),
                  ),
                  CupertinoListTile(
                    leading: const Icon(CupertinoIcons.slider_horizontal_3),
                    title: const Text('Manual Word Filter', style: TextStyle(fontSize: 15)),
                    subtitle: const Text('Hide comments that contain specific words.', style: TextStyle(fontSize: 12)),
                    trailing: CupertinoSwitch(
                      value: settings.comments.manualFilter,
                      onChanged: (val) {
                        ref.read(userSettingsProvider.notifier).updateComments(manualFilter: val);
                      },
                    ),
                  ),
                  if (settings.comments.manualFilter)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: CupertinoTextField(
                        controller: _wordController,
                        placeholder: 'Enter words separated by commas (e.g. spam, hate)',
                        placeholderStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                        style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
                        ),
                        onSubmitted: (val) {
                          final words = val.split(',').map((w) => w.trim()).where((w) => w.isNotEmpty).toList();
                          ref.read(userSettingsProvider.notifier).updateComments(filteredWords: words);
                        },
                      ),
                    ),
                  CupertinoListTile(
                    leading: const Icon(LucideIcons.heart),
                    title: const Text('Allow Comment Likes', style: TextStyle(fontSize: 15)),
                    trailing: CupertinoSwitch(
                      value: settings.comments.allowCommentLikes,
                      onChanged: (val) {
                        ref.read(userSettingsProvider.notifier).updateComments(allowCommentLikes: val);
                      },
                    ),
                  ),
                ],
              ),

              // ─── LIKES & SHARES ──────────────────────────────
              _buildSectionHeader('Likes and Shares'),
              CupertinoListSection.insetGrouped(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                backgroundColor: Colors.transparent,
                children: [
                  CupertinoListTile(
                    leading: const Icon(LucideIcons.eye_off),
                    title: const Text('Hide Like Counts', style: TextStyle(fontSize: 15)),
                    subtitle: const Text('Hide likes count on your posts.', style: TextStyle(fontSize: 12)),
                    trailing: CupertinoSwitch(
                      value: settings.likesAndShares.hideLikeCount,
                      onChanged: (val) {
                        ref.read(userSettingsProvider.notifier).updateLikesShares(hideLikeCount: val);
                      },
                    ),
                  ),
                  CupertinoListTile(
                    leading: const Icon(LucideIcons.eye),
                    title: const Text('Hide Others\' Like Counts', style: TextStyle(fontSize: 15)),
                    subtitle: const Text('Hide likes count on other users\' posts.', style: TextStyle(fontSize: 12)),
                    trailing: CupertinoSwitch(
                      value: settings.likesAndShares.hideOthersLikeCount,
                      onChanged: (val) {
                        ref.read(userSettingsProvider.notifier).updateLikesShares(hideOthersLikeCount: val);
                      },
                    ),
                  ),
                  CupertinoListTile(
                    leading: const Icon(LucideIcons.repeat),
                    title: const Text('Allow Sharing to Stories', style: TextStyle(fontSize: 15)),
                    trailing: CupertinoSwitch(
                      value: settings.likesAndShares.allowStorySharing,
                      onChanged: (val) {
                        ref.read(userSettingsProvider.notifier).updateLikesShares(allowStorySharing: val);
                      },
                    ),
                  ),
                  CupertinoListTile(
                    leading: const Icon(LucideIcons.repeat_2),
                    title: const Text('Allow Reel Sharing', style: TextStyle(fontSize: 15)),
                    trailing: CupertinoSwitch(
                      value: settings.likesAndShares.allowReelSharing,
                      onChanged: (val) {
                        ref.read(userSettingsProvider.notifier).updateLikesShares(allowReelSharing: val);
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
              opt.toUpperCase(),
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
