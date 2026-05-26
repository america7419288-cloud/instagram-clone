import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../providers/ad_provider.dart';
import '../data/repositories/ad_service.dart';
import '../models/campaign_model.dart';

class AdminCampaignsPage extends ConsumerStatefulWidget {
  const AdminCampaignsPage({super.key});

  @override
  ConsumerState<AdminCampaignsPage> createState() => _AdminCampaignsPageState();
}

class _AdminCampaignsPageState extends ConsumerState<AdminCampaignsPage> {
  List<CampaignModel> _pendingCampaigns = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    setState(() => _loading = true);
    try {
      final list = await ref.read(adServiceProvider).getAllCampaigns(status: 'pending_review');
      setState(() {
        _pendingCampaigns = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(String id) async {
    HapticFeedback.mediumImpact();
    try {
      await ref.read(adServiceProvider).approveCampaign(id);
      setState(() {
        _pendingCampaigns.removeWhere((c) => c.id == id);
      });
      _showToast('Campaign Approved');
    } catch (e) {
      _showToast('Approve failed: ${e.toString()}');
    }
  }

  Future<void> _reject(String id) async {
    final reasonController = TextEditingController();
    HapticFeedback.selectionClick();
    
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Reject Campaign'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: reasonController,
            placeholder: 'Reason (e.g. Policy Violation)',
            style: const TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Reject'),
            onPressed: () async {
              Navigator.pop(context);
              HapticFeedback.mediumImpact();
              try {
                await ref.read(adServiceProvider).rejectCampaign(id, reasonController.text.trim());
                setState(() {
                  _pendingCampaigns.removeWhere((c) => c.id == id);
                });
                _showToast('Campaign Rejected');
              } catch (e) {
                _showToast('Reject failed: ${e.toString()}');
              }
            },
          ),
        ],
      ),
    );
  }

  void _showToast(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : Colors.black;

    return CupertinoPageScaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF9F9F9),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: isDark ? Colors.black.withOpacity(0.8) : Colors.white.withOpacity(0.8),
        middle: Text(
          'Admin Review Deck',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : _pendingCampaigns.isEmpty
                ? _buildEmptyState(isDark)
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingCampaigns.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, idx) {
                      final c = _pendingCampaigns[idx];
                      return _buildReviewCard(c, isDark);
                    },
                  ),
      ),
    );
  }

  Widget _buildReviewCard(CampaignModel c, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.store, size: 18, color: isDark ? Colors.white54 : Colors.black54),
              const SizedBox(width: 8),
              Text(
                c.businessName ?? 'Advertiser Account',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            c.name,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          _buildRow('Objective', c.objective.toUpperCase(), isDark),
          _buildRow('Budget', '\$${(c.budgetAmount / 100).toStringAsFixed(2)} (${c.budgetType})', isDark),
          _buildRow('Targeting', 'Age: ${c.targeting["ageMin"]}-${c.targeting["ageMax"]}, Gender: ${c.targeting["gender"]}', isDark),
          if (c.targeting["interests"] != null && (c.targeting["interests"] as List).isNotEmpty)
            _buildRow('Interests', (c.targeting["interests"] as List).join(', '), isDark),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                color: CupertinoColors.destructiveRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                onPressed: () => _reject(c.id),
                child: const Text('Reject', style: TextStyle(color: CupertinoColors.destructiveRed, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(width: 12),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                color: const Color(0xFF0095F6),
                borderRadius: BorderRadius.circular(8),
                onPressed: () => _approve(c.id),
                child: const Text('Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(color: isDark ? Colors.white30 : Colors.black30, fontSize: 12, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.check_check, size: 48, color: isDark ? Colors.white24 : Colors.black24),
          const SizedBox(height: 16),
          Text(
            'Inbox is Clear',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No campaigns are currently pending review.',
            style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
