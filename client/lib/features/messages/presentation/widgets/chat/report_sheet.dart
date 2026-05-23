// lib/features/messages/presentation/widgets/chat/report_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class ReportSheet extends StatefulWidget {
  final String targetName;
  final Future<void> Function(String type, String description) onSubmitReport;

  const ReportSheet({
    super.key,
    required this.targetName,
    required this.onSubmitReport,
  });

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0; // 0: Reason selection, 1: Loading, 2: Success Checkmark
  String? _selectedReason;
  final TextEditingController _descController = TextEditingController();
  
  late AnimationController _checkController;
  late Animation<double> _checkScale;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkScale = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _descController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  final Map<String, String> _reasons = {
    "It's spam": "spam",
    "Harassment or bullying": "harassment",
    "Hate speech or symbols": "hate_speech",
    "Violence or dangerous organizations": "violence",
    "Nudity or sexual activity": "nudity",
    "Scam or fraud": "scam",
    "Something else": "other",
  };

  void _submit(String reason) async {
    setState(() {
      _selectedReason = reason;
      _currentStep = 1; // Loading
    });

    try {
      await widget.onSubmitReport(reason, _descController.text);
      
      // Cooldown & validation passed, animate success
      if (mounted) {
        setState(() {
          _currentStep = 2; // Success
        });
        HapticFeedback.mediumImpact();
        _checkController.forward(from: 0.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentStep = 0; // Fall back to reason
        });
        
        // Show error snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('429') 
                  ? 'You have already reported this target recently.'
                  : 'Failed to submit report. Please try again.',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFED4956),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 8,
      ),
      child: SafeArea(
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _buildContent(isDark),
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_currentStep == 1) {
      return const SizedBox(
        height: 250,
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFED4956),
          ),
        ),
      );
    }

    if (_currentStep == 2) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ScaleTransition(
              scale: _checkScale,
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFF09C167),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Thank You',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Your report has been submitted for review. We use these reports to keep our community safe. You've helped make Instagram a better place.",
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0095F6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    }

    // Step 0: Reasons list
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Drag handle
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white30 : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 20),
        
        Text(
          'Report',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            'Why are you reporting this ${widget.targetName}?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
        
        ..._reasons.entries.map((entry) {
          return Column(
            children: [
              ListTile(
                title: Text(
                  entry.key,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey,
                ),
                onTap: () => _submit(entry.value),
              ),
              const Divider(height: 1),
            ],
          );
        }),
        
        const SizedBox(height: 8),
      ],
    );
  }
}
