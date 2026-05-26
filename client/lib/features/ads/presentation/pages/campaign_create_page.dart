import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../providers/ad_provider.dart';
import 'creative_create_page.dart';

class CampaignCreatePage extends ConsumerStatefulWidget {
  const CampaignCreatePage({super.key});

  @override
  ConsumerState<CampaignCreatePage> createState() => _CampaignCreatePageState();
}

class _CampaignCreatePageState extends ConsumerState<CampaignCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController();
  final _bidController = TextEditingController();
  final _interestsController = TextEditingController();
  final _locationsController = TextEditingController();

  String _objective = 'awareness';
  String _budgetType = 'daily';
  String _bidStrategy = 'lowest_cost';
  
  double _ageMin = 18.0;
  double _ageMax = 65.0;
  String _gender = 'all';

  bool _placementFeed = true;
  bool _placementReels = true;
  bool _placementStories = true;
  
  bool _submitting = false;

  final List<Map<String, String>> _objectives = const [
    {'value': 'awareness', 'label': 'Brand Awareness (Impressions)'},
    {'value': 'traffic', 'label': 'Website Traffic (Clicks)'},
    {'value': 'engagement', 'label': 'Post Engagement (Likes/Shares)'},
    {'value': 'app_installs', 'label': 'App Installs'},
    {'value': 'conversions', 'label': 'Conversions (Sales/Leads)'},
    {'value': 'video_views', 'label': 'Video Views'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    _bidController.dispose();
    _interestsController.dispose();
    _locationsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate budget
    final budgetAmountCents = (double.parse(_budgetController.text.trim()) * 100).toInt();
    if (budgetAmountCents < 100) {
      _showError('Minimum budget is \$1.00');
      return;
    }

    final bidCents = _bidController.text.trim().isNotEmpty
        ? (double.parse(_bidController.text.trim()) * 100).toInt()
        : null;

    // Parse targeting lists
    final interestsList = _interestsController.text.trim().isNotEmpty
        ? _interestsController.text.split(',').map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty).toList()
        : <String>[];

    final rawLocations = _locationsController.text.trim().isNotEmpty
        ? _locationsController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : <String>[];
    
    final locationsList = rawLocations.map((loc) => {'country': loc}).toList();

    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();

    try {
      final campaign = await ref.read(campaignsListProvider.notifier).create(
        name: _nameController.text.trim(),
        objective: _objective,
        budgetType: _budgetType,
        budgetAmount: budgetAmountCents,
        bidStrategy: _bidStrategy,
        bidAmount: bidCents,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)), // Default 30 days
        activeDays: [0, 1, 2, 3, 4, 5, 6],
        activeHoursStart: 0,
        activeHoursEnd: 23,
        targeting: {
          'ageMin': _ageMin.toInt(),
          'ageMax': _ageMax.toInt(),
          'gender': _gender,
          'interests': interestsList,
          'locations': locationsList,
        },
        placements: {
          'feed': _placementFeed,
          'reels': _placementReels,
          'stories': _placementStories,
          'explore': false,
        },
      );

      if (mounted) {
        // Redirect directly to upload Creative for this campaign
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(
            builder: (_) => CreativeCreatePage(campaignId: campaign.id),
          ),
        );
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
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
    final secondaryColor = isDark ? Colors.white70 : Colors.black87;

    return CupertinoPageScaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF9F9F9),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: isDark ? Colors.black.withOpacity(0.8) : Colors.white.withOpacity(0.8),
        middle: Text(
          'Create Campaign',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Section 1: Campaign details
                _buildSectionHeader('Campaign Details', isDark),
                _buildCard(
                  isDark: isDark,
                  children: [
                    _buildLabel('Campaign Name *', isDark),
                    _buildTextField(
                      controller: _nameController,
                      placeholder: 'e.g. Summer Promo 2026',
                      isDark: isDark,
                      validator: (value) => value == null || value.trim().isEmpty ? 'Campaign name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildLabel('Marketing Objective *', isDark),
                    _buildDropdown(
                      value: _objective,
                      isDark: isDark,
                      items: _objectives.map((obj) {
                        return DropdownMenuItem<String>(
                          value: obj['value'],
                          child: Text(obj['label']!),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _objective = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Section 2: Budget
                _buildSectionHeader('Budget & Bidding', isDark),
                _buildCard(
                  isDark: isDark,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Budget Type *', isDark),
                              _buildDropdown(
                                value: _budgetType,
                                isDark: isDark,
                                items: const [
                                  DropdownMenuItem(value: 'daily', child: Text('Daily Budget')),
                                  DropdownMenuItem(value: 'lifetime', child: Text('Lifetime Budget')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _budgetType = val);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Amount (USD) *', isDark),
                              _buildTextField(
                                controller: _budgetController,
                                placeholder: '10.00',
                                isDark: isDark,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) return 'Required';
                                  if (double.tryParse(value) == null) return 'Must be a number';
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Bidding Strategy', isDark),
                              _buildDropdown(
                                value: _bidStrategy,
                                isDark: isDark,
                                items: const [
                                  DropdownMenuItem(value: 'lowest_cost', child: Text('Lowest Cost')),
                                  DropdownMenuItem(value: 'cost_cap', child: Text('Cost Cap')),
                                  DropdownMenuItem(value: 'bid_cap', child: Text('Bid Cap')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _bidStrategy = val);
                                },
                              ),
                            ],
                          ),
                        ),
                        if (_bidStrategy != 'lowest_cost') ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Max Bid (USD)', isDark),
                                _buildTextField(
                                  controller: _bidController,
                                  placeholder: '0.50',
                                  isDark: isDark,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Section 3: Audience
                _buildSectionHeader('Audience Targeting', isDark),
                _buildCard(
                  isDark: isDark,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildLabel('Age Range', isDark),
                        Text(
                          '${_ageMin.toInt()} - ${_ageMax.toInt()}',
                          style: TextStyle(color: secondaryColor, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    RangeSlider(
                      values: RangeValues(_ageMin, _ageMax),
                      min: 13.0,
                      max: 65.0,
                      divisions: 52,
                      activeColor: const Color(0xFF0095F6),
                      inactiveColor: isDark ? Colors.white10 : Colors.black12,
                      onChanged: (RangeValues vals) {
                        setState(() {
                          _ageMin = vals.start;
                          _ageMax = vals.end;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildLabel('Gender', isDark),
                    CupertinoSegmentedControl<String>(
                      groupValue: _gender,
                      selectedColor: const Color(0xFF0095F6),
                      unselectedColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                      borderColor: const Color(0xFF0095F6),
                      onValueChanged: (val) => setState(() => _gender = val),
                      children: {
                        'all': Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text('All', style: TextStyle(color: _gender == 'all' ? Colors.white : secondaryColor, fontSize: 13)),
                        ),
                        'male': Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text('Men', style: TextStyle(color: _gender == 'male' ? Colors.white : secondaryColor, fontSize: 13)),
                        ),
                        'female': Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text('Women', style: TextStyle(color: _gender == 'female' ? Colors.white : secondaryColor, fontSize: 13)),
                        ),
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildLabel('Locations (Comma separated countries/cities)', isDark),
                    _buildTextField(
                      controller: _locationsController,
                      placeholder: 'e.g. United States, California, London',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildLabel('Interests (Comma separated topics)', isDark),
                    _buildTextField(
                      controller: _interestsController,
                      placeholder: 'e.g. fitness, gaming, software, travel',
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Section 4: Placements
                _buildSectionHeader('Ad Placements', isDark),
                _buildCard(
                  isDark: isDark,
                  children: [
                    _buildSwitchTile('Feed Feed Injection', _placementFeed, isDark, (val) => setState(() => _placementFeed = val)),
                    _buildSwitchTile('Reels Video Injection', _placementReels, isDark, (val) => setState(() => _placementReels = val)),
                    _buildSwitchTile('Stories Sponsored Circle', _placementStories, isDark, (val) => setState(() => _placementStories = val)),
                  ],
                ),
                const SizedBox(height: 40),

                // Submit Button
                CupertinoButton(
                  color: const Color(0xFF0095F6),
                  borderRadius: BorderRadius.circular(10),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : const Text(
                          'Save & Continue to Creative Upload',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                        ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: isDark ? Colors.white38 : Colors.black38,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildCard({required bool isDark, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? Colors.white70 : Colors.black87,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool val, bool isDark, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14)),
          CupertinoSwitch(
            value: val,
            activeColor: const Color(0xFF0095F6),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String placeholder,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
        filled: true,
        fillColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF0095F6), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: CupertinoColors.destructiveRed, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: CupertinoColors.destructiveRed, width: 1.5),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildDropdown({
    required String value,
    required bool isDark,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14),
          icon: Icon(LucideIcons.chevron_down, color: isDark ? Colors.white54 : Colors.black45, size: 18),
          isExpanded: true,
          onChanged: onChanged,
          items: items,
        ),
      ),
    );
  }
}
