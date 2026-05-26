import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/ad_provider.dart';
import '../../data/models/campaign_model.dart';
import 'campaign_create_page.dart';
import 'creative_create_page.dart';
import 'admin_campaigns_page.dart';

class AdDashboardPage extends ConsumerStatefulWidget {
  const AdDashboardPage({super.key});

  @override
  ConsumerState<AdDashboardPage> createState() => _AdDashboardPageState();
}

class _AdDashboardPageState extends ConsumerState<AdDashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(campaignsListProvider.notifier).loadCampaigns();
      ref.invalidate(advertiserOverviewProvider);
    });
  }

  Future<void> _refresh() async {
    HapticFeedback.lightImpact();
    ref.read(campaignsListProvider.notifier).loadCampaigns();
    ref.invalidate(advertiserOverviewProvider);
  }

  void _toggleCampaignStatus(CampaignModel campaign) {
    HapticFeedback.mediumImpact();
    final notifier = ref.read(campaignsListProvider.notifier);
    if (campaign.status == 'active') {
      notifier.pause(campaign.id);
    } else {
      notifier.resume(campaign.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : Colors.black;
    final advertiserState = ref.watch(advertiserProvider);
    final campaignsState = ref.watch(campaignsListProvider);
    final overviewAsync = ref.watch(advertiserOverviewProvider);
    final currentUser = ref.watch(currentUserProvider);

    final isAdmin = currentUser?.isVerified ?? false;

    return CupertinoPageScaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF9F9F9),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: isDark ? Colors.black.withOpacity(0.8) : Colors.white.withOpacity(0.8),
        middle: Text(
          'Ads Manager',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
        trailing: isAdmin
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Text('Admin Panel', style: TextStyle(color: Color(0xFF0095F6), fontWeight: FontWeight.w600)),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (_) => const AdminCampaignsPage()),
                  );
                },
              )
            : null,
      ),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: const Color(0xFF0095F6),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Overview metrics card deck
                overviewAsync.when(
                  loading: () => const Center(child: CupertinoActivityIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
                  data: (data) {
                    final overview = data['overview'] ?? {};
                    final spendDollars = ((overview['totalSpend'] ?? 0) / 100).toStringAsFixed(2);
                    
                    return Column(
                      children: [
                        _buildMetricSummaryCard(spendDollars, overview, isDark),
                        const SizedBox(height: 20),
                      ],
                    );
                  },
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Campaigns',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'SF-Pro',
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          CupertinoPageRoute(builder: (_) => const CampaignCreatePage()),
                        );
                      },
                      child: const Row(
                        children: [
                          Icon(LucideIcons.plus, size: 16, color: Color(0xFF0095F6)),
                          SizedBox(width: 4),
                          Text('Create', style: TextStyle(color: Color(0xFF0095F6), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (campaignsState.isLoading && campaignsState.campaigns.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CupertinoActivityIndicator()),
                  )
                else if (campaignsState.campaigns.isEmpty)
                  _buildEmptyCampaigns(isDark)
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: campaignsState.campaigns.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, idx) {
                      final campaign = campaignsState.campaigns[idx];
                      return _buildCampaignCard(campaign, isDark);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricSummaryCard(String spendDollars, Map<dynamic, dynamic> overview, bool isDark) {
    final isL = isDark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isL
              ? [const Color(0xFF1E1E1E), const Color(0xFF151515)]
              : [Colors.white, const Color(0xFFF2F2F7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: isL ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Total Spend (USD)',
            style: TextStyle(color: isL ? Colors.white54 : Colors.black54, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            '\$$spendDollars',
            style: TextStyle(
              color: isL ? Colors.white : Colors.black,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 20),
          Divider(color: isL ? Colors.white10 : Colors.black12),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricSubItem(
                'Impressions',
                _formatCount(overview['totalImpressions'] ?? 0),
                isL,
              ),
              _buildMetricSubItem(
                'Clicks',
                _formatCount(overview['totalClicks'] ?? 0),
                isL,
              ),
              _buildMetricSubItem(
                'Avg. CTR',
                '${overview['averageCtr'] ?? "0.00"}%',
                isL,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricSubItem(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildCampaignCard(CampaignModel campaign, bool isDark) {
    final statusColor = _getStatusColor(campaign.status);
    final isL = isDark;

    return Container(
      decoration: BoxDecoration(
        color: isL ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isL ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  campaign.name,
                  style: TextStyle(
                    color: isL ? Colors.white : Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                campaign.status.toUpperCase().replaceAll('_', ' '),
                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCampaignMeta('Spend', '\$${(campaign.budgetSpent / 100).toStringAsFixed(2)}', isL),
              _buildCampaignMeta('Imps', _formatCount(campaign.impressions), isL),
              _buildCampaignMeta('Clicks', _formatCount(campaign.clicks), isL),
              _buildCampaignMeta('CTR', '${campaign.ctr.toStringAsFixed(2)}%', isL),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: isL ? Colors.white10 : Colors.black12, height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Edit/Add Creative
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(LucideIcons.image_plus, size: 14, color: isL ? Colors.white70 : Colors.black87),
                    const SizedBox(width: 4),
                    Text('+ Ad Media', style: TextStyle(fontSize: 12, color: isL ? Colors.white70 : Colors.black87)),
                  ],
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (_) => CreativeCreatePage(campaignId: campaign.id)),
                  );
                },
              ),
              const Spacer(),
              // Toggle Status
              if (campaign.status == 'active' || campaign.status == 'paused')
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    campaign.status == 'active' ? 'Pause' : 'Resume',
                    style: TextStyle(
                      fontSize: 13,
                      color: campaign.status == 'active' ? CupertinoColors.systemOrange : const Color(0xFF0095F6),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () => _toggleCampaignStatus(campaign),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignMeta(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCampaigns(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Center(
        child: Column(
          children: [
            Icon(LucideIcons.megaphone, size: 48, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 16),
            Text(
              'No campaigns yet',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Launch your first sponsored post to reach millions of users.',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            CupertinoButton(
              color: const Color(0xFF0095F6),
              borderRadius: BorderRadius.circular(10),
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (_) => const CampaignCreatePage()),
                );
              },
              child: const Text('Create First Campaign', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return CupertinoColors.systemGreen;
      case 'paused':
        return CupertinoColors.systemOrange;
      case 'pending_review':
        return CupertinoColors.systemYellow;
      case 'rejected':
        return CupertinoColors.systemRed;
      case 'completed':
        return CupertinoColors.systemGrey;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  String _formatCount(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return '$number';
  }
}
