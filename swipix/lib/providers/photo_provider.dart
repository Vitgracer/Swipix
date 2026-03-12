import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import '../models/photo_item.dart';
import '../services/photo_service.dart';
import '../services/file_service.dart';

enum SwipeAction { keep, trash }

/// Item representing an action that can be undone
class UndoItem {
  final PhotoItem photo;
  final SwipeAction action;
  final String? trashFileName;
  
  UndoItem({
    required this.photo, 
    required this.action, 
    this.trashFileName,
  });
}

class PhotoState {
  final List<PhotoItem> photos;
  final List<AssetPathEntity> albums;
  final AssetPathEntity? selectedAlbum;
  final bool isLoading;
  final bool isPermissionGranted;
  final List<UndoItem> undoStack;
  final Set<String> globalKeptIds;
  final Map<String, String> trashPathMap; // Filename -> OriginalPath mapping
  final int keptCount;
  final int trashCount;
  final double storageSaved;

  PhotoState({
    this.photos = const [],
    this.albums = const [],
    this.selectedAlbum,
    this.isLoading = false,
    this.isPermissionGranted = false,
    this.undoStack = const [],
    this.globalKeptIds = const {},
    this.trashPathMap = const {},
    this.keptCount = 0,
    this.trashCount = 0,
    this.storageSaved = 0.0,
  });

  PhotoState copyWith({
    List<PhotoItem>? photos,
    List<AssetPathEntity>? albums,
    AssetPathEntity? selectedAlbum,
    bool? isLoading,
    bool? isPermissionGranted,
    List<UndoItem>? undoStack,
    Set<String>? globalKeptIds,
    Map<String, String>? trashPathMap,
    int? keptCount,
    int? trashCount,
    double? storageSaved,
  }) {
    return PhotoState(
      photos: photos ?? this.photos,
      albums: albums ?? this.albums,
      selectedAlbum: selectedAlbum ?? this.selectedAlbum,
      isLoading: isLoading ?? this.isLoading,
      isPermissionGranted: isPermissionGranted ?? this.isPermissionGranted,
      undoStack: undoStack ?? this.undoStack,
      globalKeptIds: globalKeptIds ?? this.globalKeptIds,
      trashPathMap: trashPathMap ?? this.trashPathMap,
      keptCount: keptCount ?? this.keptCount,
      trashCount: trashCount ?? this.trashCount,
      storageSaved: storageSaved ?? this.storageSaved,
    );
  }
}

class PhotoNotifier extends StateNotifier<PhotoState> {
  final PhotoService _photoService = PhotoService();
  final FileService _fileService = FileService();
  
  static const String _kKeptKey = 'kept_photo_ids';
  static const String _kTrashPathMapKey = 'trash_path_map';

  PhotoNotifier() : super(PhotoState()) {
    init();
  }

  /// Initialize application state and load persistent data
  Future<void> init() async {
    state = state.copyWith(isLoading: true);
    final prefs = await SharedPreferences.getInstance();
    
    // Load IDs of photos the user chose to keep
    final keptList = prefs.getStringList(_kKeptKey) ?? [];
    
    // Load trash recovery mapping (Filename|OriginalPath)
    final trashPathList = prefs.getStringList(_kTrashPathMapKey) ?? [];
    final Map<String, String> trashMap = {};
    for (var item in trashPathList) {
      final parts = item.split('|');
      if (parts.length == 2) trashMap[parts[0]] = parts[1];
    }
    
    final granted = await _photoService.requestPermissions();
    if (granted) {
      final albums = await _photoService.getAlbums();
      state = state.copyWith(
        isPermissionGranted: true, 
        albums: albums, 
        globalKeptIds: keptList.toSet(),
        trashPathMap: trashMap,
      );
      if (albums.isNotEmpty) await selectAlbum(albums.first);
    } else {
      state = state.copyWith(isPermissionGranted: false, isLoading: false);
    }
  }

  /// Refresh album list to sync counts
  Future<void> refreshAlbums() async {
    final albums = await _photoService.getAlbums();
    state = state.copyWith(albums: albums);
  }

  /// Calculate remaining items to review in a specific album
  Future<int> getRemainingCount(AssetPathEntity album) async {
    final totalCount = await album.assetCountAsync;
    if (totalCount == 0) return 0;
    
    final assets = await album.getAssetListRange(start: 0, end: totalCount);
    return assets.where((a) => !state.globalKeptIds.contains(a.id)).length;
  }

  /// Switch currently reviewed album
  Future<void> selectAlbum(AssetPathEntity album) async {
    state = state.copyWith(
      isLoading: true, 
      selectedAlbum: album, 
      photos: [], 
      undoStack: [], 
      keptCount: 0, 
      trashCount: 0,
    );
    
    final assets = await _photoService.getPhotosFromAlbum(album);
    final photos = assets
        .where((a) => !state.globalKeptIds.contains(a.id))
        .map((a) => PhotoItem(asset: a))
        .toList();
        
    state = state.copyWith(photos: photos, isLoading: false);
  }

  /// Handle "Trash" action (move to app folder)
  Future<void> swipeLeft(PhotoItem photo) async {
    final file = await photo.asset.file;
    if (file != null) {
      final size = await file.length();
      final originalPath = file.path;
      final uniqueTrashName = await _fileService.forceMoveToTrash(file);
      
      if (uniqueTrashName != null) {
        final newTrashMap = {...state.trashPathMap, uniqueTrashName: originalPath};
        await _saveTrashMap(newTrashMap);

        state = state.copyWith(
          photos: state.photos.where((p) => p.id != photo.id).toList(),
          undoStack: [...state.undoStack, UndoItem(photo: photo, action: SwipeAction.trash, trashFileName: uniqueTrashName)],
          trashPathMap: newTrashMap,
          trashCount: state.trashCount + 1,
          storageSaved: state.storageSaved + (size / (1024 * 1024)),
        );
        await refreshAlbums();
      }
    }
  }

  /// Handle "Keep" action (save to persistent registry)
  Future<void> swipeRight(PhotoItem photo) async {
    final newKeptIds = {...state.globalKeptIds, photo.id};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kKeptKey, newKeptIds.toList());

    state = state.copyWith(
      photos: state.photos.where((p) => p.id != photo.id).toList(),
      globalKeptIds: newKeptIds,
      undoStack: [...state.undoStack, UndoItem(photo: photo, action: SwipeAction.keep)],
      keptCount: state.keptCount + 1,
    );
  }

  /// Undo the last action
  Future<void> undo() async {
    if (state.undoStack.isEmpty) return;
    final lastUndo = state.undoStack.last;
    final photo = lastUndo.photo;

    if (lastUndo.action == SwipeAction.trash && lastUndo.trashFileName != null) {
      final originalPath = state.trashPathMap[lastUndo.trashFileName!];
      if (originalPath != null) {
        final success = await _fileService.restoreFromTrash(lastUndo.trashFileName!, originalPath);
        if (success) {
           final newTrashMap = Map<String, String>.from(state.trashPathMap)..remove(lastUndo.trashFileName!);
           await _saveTrashMap(newTrashMap);
           state = state.copyWith(trashPathMap: newTrashMap);
           await refreshAlbums();
        } else {
          return;
        }
      }
    } else if (lastUndo.action == SwipeAction.keep) {
      final newKeptIds = state.globalKeptIds.where((id) => id != photo.id).toSet();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kKeptKey, newKeptIds.toList());
      state = state.copyWith(globalKeptIds: newKeptIds);
    }

    state = state.copyWith(
      photos: [photo, ...state.photos],
      undoStack: state.undoStack.sublist(0, state.undoStack.length - 1),
      trashCount: lastUndo.action == SwipeAction.trash ? (state.trashCount - 1).clamp(0, 999999) : state.trashCount,
      keptCount: lastUndo.action == SwipeAction.keep ? (state.keptCount - 1).clamp(0, 999999) : state.keptCount,
    );
  }

  /// Restore specific file from the vault
  Future<void> restoreSpecific(File file) async {
    final fileName = p.basename(file.path);
    final originalPath = state.trashPathMap[fileName];
    if (originalPath != null) {
      final success = await _fileService.restoreFromTrash(fileName, originalPath);
      if (success) {
        final newTrashMap = Map<String, String>.from(state.trashPathMap)..remove(fileName);
        await _saveTrashMap(newTrashMap);
        state = state.copyWith(
          trashCount: (state.trashCount - 1).clamp(0, 999999),
          trashPathMap: newTrashMap,
        );
        await refreshAlbums();
      }
    }
  }

  Future<void> _saveTrashMap(Map<String, String> map) async {
    final prefs = await SharedPreferences.getInstance();
    final list = map.entries.map((e) => '${e.key}|${e.value}').toList();
    await prefs.setStringList(_kTrashPathMapKey, list);
  }

  /// Permanently delete all items from the app vault
  Future<void> clearTrash() async {
    await _fileService.clearAppTrash();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTrashPathMapKey);
    state = state.copyWith(trashCount: 0, storageSaved: 0.0, trashPathMap: {});
    await refreshAlbums();
  }
}

final photoProvider = StateNotifierProvider<PhotoNotifier, PhotoState>((ref) => PhotoNotifier());
