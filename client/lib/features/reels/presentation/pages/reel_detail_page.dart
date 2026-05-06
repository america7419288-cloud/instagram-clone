// lib/features/reels/presentation/pages/reel_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/error_view.dart';
import '../../data/models/reel_model.dart';
import '../../data/repositories/reel_service.dart';
import '../widgets/reel_card.dart';

class ReelDetailPage extends ConsumerStatefulWidget {
  final String reelId;
  const ReelDetailPage({super.key, required this.reelId});

  @override
  ConsumerState<ReelDetailPage> createState() => _ReelDetailPageState();
}

class _ReelDetailPageState extends ConsumerState<ReelDetailPage> {
  ReelModel? _reel;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReel();
  }

  Future<void> _loadReel() async {
    try {
      final reel = await ref.read(reelServiceProvider).getReelById(widget.reelId);
      if (mounted) {
        setState(() {
          _reel = reel;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CupertinoActivityIndicator(color: Colors.white),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: ErrorView(
          message: _error,
          onRetry: _loadReel,
        ),
      );
    }

    if (_reel == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Reel not found', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          ReelCard(
            reel: _reel!,
            isActive: true,
          ),
          // Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
              onPressed: () => context.pop(),
            ),
          ),
        ],
      ),
    );
  }
}
