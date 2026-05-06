// lib/features/post/presentation/providers/media_picker_provider.dart

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter_riverpod/legacy.dart';

enum CreateMode { post, story, reel, live }

class MediaPickerState {
  final CreateMode mode;
  final List<AssetPathEntity> albums;
  final AssetPathEntity? selectedAlbum;
  final List<AssetEntity> assets;
  final AssetEntity? selectedAsset;
  final List<AssetEntity> selectedAssets;
  final bool isMultiSelect;
  final bool isLoading;
  final String? error;

  const MediaPickerState({
    this.mode = CreateMode.post,
    this.albums = const [],
    this.selectedAlbum,
    this.assets = const [],
    this.selectedAsset,
    this.selectedAssets = const [],
    this.isMultiSelect = false,
    this.isLoading = false,
    this.error,
  });

  MediaPickerState copyWith({
    CreateMode? mode,
    List<AssetPathEntity>? albums,
    AssetPathEntity? selectedAlbum,
    List<AssetEntity>? assets,
    AssetEntity? selectedAsset,
    List<AssetEntity>? selectedAssets,
    bool? isMultiSelect,
    bool? isLoading,
    String? error,
  }) {
    return MediaPickerState(
      mode: mode ?? this.mode,
      albums: albums ?? this.albums,
      selectedAlbum: selectedAlbum ?? this.selectedAlbum,
      assets: assets ?? this.assets,
      selectedAsset: selectedAsset ?? this.selectedAsset,
      selectedAssets: selectedAssets ?? this.selectedAssets,
      isMultiSelect: isMultiSelect ?? this.isMultiSelect,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class MediaPickerNotifier extends StateNotifier<MediaPickerState> {
  MediaPickerNotifier() : super(const MediaPickerState());

  Future<void> initialize() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      // Small delay can prevent race conditions on some devices
      await Future.delayed(const Duration(milliseconds: 100));

      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      debugPrint('PhotoManager permission state: $ps');
      
      if (ps == PermissionState.authorized || ps == PermissionState.limited) {
        await loadAlbums();
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Gallery permission: ${ps.name}. Please enable it in settings.',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Initialization failed: $e');
    }
  }

  Future<void> loadAlbums() async {
    try {
      // Fetch only the "Recent" album first for maximum speed
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        onlyAll: true, 
      );
      
      if (albums.isNotEmpty) {
        state = state.copyWith(
          albums: albums,
          selectedAlbum: albums.first,
        );
        await loadAssets(albums.first);
        
        // After loading the first album, fetch the rest in the background
        _loadAllAlbumsInBackground();
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _loadAllAlbumsInBackground() async {
    try {
      final List<AssetPathEntity> allAlbums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
      );
      state = state.copyWith(albums: allAlbums);
    } catch (_) {
      // Ignore background load errors
    }
  }

  Future<void> loadAssets(AssetPathEntity album) async {
    try {
      state = state.copyWith(isLoading: true, selectedAlbum: album);
      final List<AssetEntity> assets = await album.getAssetListRange(
        start: 0,
        end: 100, // Load first 100
      );
      if (assets.isNotEmpty) {
        state = state.copyWith(
          assets: assets,
          selectedAsset: assets.first,
          isLoading: false,
        );
      } else {
        state = state.copyWith(assets: [], isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setMode(CreateMode mode) {
    state = state.copyWith(mode: mode);
  }

  void selectAsset(AssetEntity asset) {
    if (state.isMultiSelect) {
      final updated = List<AssetEntity>.from(state.selectedAssets);
      if (updated.contains(asset)) {
        updated.remove(asset);
      } else {
        updated.add(asset);
      }
      state = state.copyWith(
        selectedAssets: updated,
        selectedAsset: asset,
      );
    } else {
      state = state.copyWith(
        selectedAsset: asset,
        selectedAssets: [asset],
      );
    }
  }

  void toggleMultiSelect() {
    final newState = !state.isMultiSelect;
    state = state.copyWith(
      isMultiSelect: newState,
      selectedAssets: newState ? (state.selectedAsset != null ? [state.selectedAsset!] : []) : [],
    );
  }
}

final mediaPickerProvider =
    StateNotifierProvider<MediaPickerNotifier, MediaPickerState>((ref) {
  return MediaPickerNotifier();
});
