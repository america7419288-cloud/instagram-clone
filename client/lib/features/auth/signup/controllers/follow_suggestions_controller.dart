// lib/features/auth/signup/controllers/follow_suggestions_controller.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/suggested_user.dart';
import '../../../follow/data/repositories/follow_service.dart';

class FollowSuggestionsController extends ChangeNotifier {
  final FollowService _followService;
  
  FollowSuggestionsController(this._followService);
  
  // ── State ──────────────────────────────────
  
  List<SuggestedUser> _allSuggestions = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _isFollowingAll = false;
  final Set<String> _pendingFollowIds = {};

  // ── Getters ────────────────────────────────
  
  List<SuggestedUser> get allSuggestions => _allSuggestions;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;
  bool get isFollowingAll => _isFollowingAll;
  
  // Filtered by category
  List<SuggestedUser> getByCategory(SuggestionCategory category) =>
      _allSuggestions.where((u) => u.category == category).toList();
  
  // Stats
  int get totalCount => _allSuggestions.length;
  int get followedCount =>
      _allSuggestions.where((u) => u.isFollowing).length;
  bool get hasFollowedAny => followedCount > 0;
  
  // Categories that have users
  List<SuggestionCategory> get availableCategories =>
      _allSuggestions
          .map((u) => u.category)
          .toSet()
          .toList();

  // ── Initialize ─────────────────────────────
  
  Future<void> loadSuggestions() async {
    _isLoading = true;
    _hasError = false;
    _errorMessage = null;
    notifyListeners();

    try {
      final rawData = await _followService.getSuggestions();
      if (rawData.isEmpty) {
        _allSuggestions = [];
      } else {
        _allSuggestions = rawData.map((e) => SuggestedUser.fromJson(e)).toList();
      }
    } catch (e) {
      _hasError = true;
      _errorMessage = 'Couldn\'t load suggestions: ${e.toString().replaceAll('Exception: ', '')}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> retry() async {
    await loadSuggestions();
  }

  // ── Follow Actions ─────────────────────────
  
  Future<void> toggleFollow(String userId) async {
    final idx = _allSuggestions.indexWhere(
        (u) => u.id == userId);
    if (idx == -1) return;
    
    if (_pendingFollowIds.contains(userId)) return;
    
    final user = _allSuggestions[idx];
    final newFollowState = !user.isFollowing;
    
    // Optimistic update
    _pendingFollowIds.add(userId);
    _allSuggestions[idx] = user.copyWith(
      isFollowing: newFollowState,
      isFollowingPending: true,
    );
    notifyListeners();
    
    HapticFeedback.lightImpact();
    
    try {
      if (newFollowState) {
        await _followService.followUser(userId);
      } else {
        await _followService.unfollowUser(userId);
      }
      
      // Update final state
      _allSuggestions[idx] = _allSuggestions[idx].copyWith(
        isFollowingPending: false,
      );
    } catch (e) {
      // Rollback on error
      _allSuggestions[idx] = user.copyWith(
        isFollowing: !newFollowState,
        isFollowingPending: false,
      );
    } finally {
      _pendingFollowIds.remove(userId);
      notifyListeners();
    }
  }
  
  Future<void> followAll() async {
    if (_isFollowingAll) return;
    
    _isFollowingAll = true;
    notifyListeners();
    HapticFeedback.mediumImpact();
    
    try {
      // Follow all unfollowed users
      final usersToFollow = <String>[];
      for (var i = 0; i < _allSuggestions.length; i++) {
        if (!_allSuggestions[i].isFollowing) {
          usersToFollow.add(_allSuggestions[i].id);
          _allSuggestions[i] = _allSuggestions[i].copyWith(
            isFollowing: true,
            isFollowingPending: true,
          );
        }
      }
      notifyListeners();
      
      // Batch API call
      for (final id in usersToFollow) {
         try {
           await _followService.followUser(id);
         } catch (_) {}
      }
      
      // Clear pending state
      for (var i = 0; i < _allSuggestions.length; i++) {
        if (_allSuggestions[i].isFollowingPending) {
          _allSuggestions[i] = _allSuggestions[i].copyWith(
            isFollowingPending: false,
          );
        }
      }
    } finally {
      _isFollowingAll = false;
      notifyListeners();
    }
  }
}
