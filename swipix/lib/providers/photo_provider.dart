import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import '../models/photo_item.dart';
import '../services/photo_service.dart';
import '../services/file_service.dart';

enum SwipeAction { keep, trash }

class UndoItem {
  final PhotoItem photo;
  final SwipeAction action;
  final String? trashFileName;
  final double sizeMb;
  
  UndoItem({
    required this.photo, 
    required this.action, 
    this.trashFileName,
    required this.sizeMb,
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
  final Map<String, String> trashPathMap;
  
  final int lifetimeKept;
  final int lifetimeTrashed;
  final double lifetimeSpaceReleased;

  final int sessionKept;
  final int sessionTrashed;

  final Map<String, int> weeklyActivity;

  PhotoState({
    this.photos = const [],
    this.albums = const [],
    this.selectedAlbum,
    this.isLoading = false,
    this.isPermissionGranted = false,
    this.undoStack = const [],
    this.globalKeptIds = const {},
    this.trashPathMap = const {},
    this.lifetimeKept = 0,
    this.lifetimeTrashed = 0,
    this.lifetimeSpaceReleased = 0.0,
    this.sessionKept = 0,
    this.sessionTrashed = 0,
    this.weeklyActivity = const {},
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
    int? lifetimeKept,
    int? lifetimeTrashed,
    double? lifetimeSpaceReleased,
    int? sessionKept,
    int? sessionTrashed,
    Map<String, int>? weeklyActivity,
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
      lifetimeKept: lifetimeKept ?? this.lifetimeKept,
      lifetimeTrashed: lifetimeTrashed ?? this.lifetimeTrashed,
      lifetimeSpaceReleased: lifetimeSpaceReleased ?? this.lifetimeSpaceReleased,
      sessionKept: sessionKept ?? this.sessionKept,
      sessionTrashed: sessionTrashed ?? this.sessionTrashed,
      weeklyActivity: weeklyActivity ?? this.weeklyActivity,
    );
  }
}

class PhotoNotifier extends StateNotifier<PhotoState> {
  final PhotoService _photoService = PhotoService();
  final FileService _fileService = FileService();
  
  static const String _kKeptKey = 'kept_photo_ids';
  static const String _kTrashPathMapKey = 'trash_path_map';
  static const String _kLifetimeKept = 'lifetime_kept';
  static const String _kLifetimeTrashed = 'lifetime_trashed';
  static const String _kLifetimeSpace = 'lifetime_space_released';
  static const String _kWeeklyActivity = 'weekly_activity';

  PhotoNotifier() : super(PhotoState()) {
    init();
  }

  Future<void> init() async {
    state = state.copyWith(isLoading: true);
    final prefs = await SharedPreferences.getInstance();
    
    final keptList = prefs.getStringList(_kKeptKey) ?? [];
    final trashPathList = prefs.getStringList(_kTrashPathMapKey) ?? [];
    final Map<String, String> trashMap = {};
    for (var item in trashPathList) {
      final parts = item.split('|');
      if (parts.length == 2) trashMap[parts[0]] = parts[1];
    }

    final lKept = prefs.getInt(_kLifetimeKept) ?? 0;
    final lTrashed = prefs.getInt(_kLifetimeTrashed) ?? 0;
    final lSpace = prefs.getDouble(_kLifetimeSpace) ?? 0.0;
    final weeklyRaw = prefs.getString(_kWeeklyActivity) ?? '{}';
    final Map<String, int> weekly = Map<String, int>.from(json.decode(weeklyRaw));
    
    final granted = await _photoService.requestPermissions();
    if (granted) {
      final albums = await _photoService.getAlbums();
      state = state.copyWith(
        isPermissionGranted: true, 
        albums: albums, 
        globalKeptIds: keptList.toSet(),
        trashPathMap: trashMap,
        lifetimeKept: lKept,
        lifetimeTrashed: lTrashed,
        lifetimeSpaceReleased: lSpace,
        weeklyActivity: weekly,
      );
      if (albums.isNotEmpty) await selectAlbum(albums.first);
    } else {
      state = state.copyWith(isPermissionGranted: false, isLoading: false);
    }
  }

  Future<int> getRemainingCount(AssetPathEntity album) async {
    final totalCount = await album.assetCountAsync;
    if (totalCount == 0) return 0;
    final assets = await album.getAssetListRange(start: 0, end: totalCount);
    return assets.where((a) => !state.globalKeptIds.contains(a.id)).length;
  }

  Future<void> selectAlbum(AssetPathEntity album) async {
    state = state.copyWith(
      isLoading: true, 
      selectedAlbum: album, 
      photos: [], 
      undoStack: [],
      sessionKept: 0,
      sessionTrashed: 0,
    );
    final assets = await _photoService.getPhotosFromAlbum(album);
    final photos = assets
        .where((a) => !state.globalKeptIds.contains(a.id))
        .map((a) => PhotoItem(asset: a))
        .toList();
    state = state.copyWith(photos: photos, isLoading: false);
  }

  Future<void> swipeLeft(PhotoItem photo) async {
    final file = await photo.asset.file;
    if (file != null) {
      final sizeMb = (await file.length()) / (1024 * 1024);
      final originalPath = file.path;
      final uniqueTrashName = await _fileService.forceMoveToTrash(file);
      
      if (uniqueTrashName != null) {
        final newTrashMap = {...state.trashPathMap, uniqueTrashName: originalPath};
        await _saveTrashMap(newTrashMap);
        _updateActivity();

        state = state.copyWith(
          photos: state.photos.where((p) => p.id != photo.id).toList(),
          undoStack: [...state.undoStack, UndoItem(photo: photo, action: SwipeAction.trash, trashFileName: uniqueTrashName, sizeMb: sizeMb)],
          trashPathMap: newTrashMap,
          lifetimeTrashed: state.lifetimeTrashed + 1,
          sessionTrashed: state.sessionTrashed + 1,
        );
        await _persistStats();
      }
    }
  }

  Future<void> swipeRight(PhotoItem photo) async {
    final newKeptIds = {...state.globalKeptIds, photo.id};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kKeptKey, newKeptIds.toList());
    _updateActivity();

    state = state.copyWith(
      photos: state.photos.where((p) => p.id != photo.id).toList(),
      globalKeptIds: newKeptIds,
      undoStack: [...state.undoStack, UndoItem(photo: photo, action: SwipeAction.keep, sizeMb: 0)],
      lifetimeKept: state.lifetimeKept + 1,
      sessionKept: state.sessionKept + 1,
    );
    await _persistStats();
  }

  Future<void> undo() async {
    if (state.undoStack.isEmpty) return;
    final lastUndo = state.undoStack.last;
    
    if (lastUndo.action == SwipeAction.trash && lastUndo.trashFileName != null) {
      final originalPath = state.trashPathMap[lastUndo.trashFileName!];
      if (originalPath != null) {
        final success = await _fileService.restoreFromTrash(lastUndo.trashFileName!, originalPath);
        if (success) {
           final newTrashMap = Map<String, String>.from(state.trashPathMap)..remove(lastUndo.trashFileName!);
           await _saveTrashMap(newTrashMap);
           state = state.copyWith(
             trashPathMap: newTrashMap,
             lifetimeTrashed: (state.lifetimeTrashed - 1).clamp(0, 9999999),
             sessionTrashed: (state.sessionTrashed - 1).clamp(0, 99999),
           );
        } else { return; }
      }
    } else if (lastUndo.action == SwipeAction.keep) {
      final newKeptIds = state.globalKeptIds.where((id) => id != lastUndo.photo.id).toSet();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kKeptKey, newKeptIds.toList());
      state = state.copyWith(
        globalKeptIds: newKeptIds,
        lifetimeKept: (state.lifetimeKept - 1).clamp(0, 9999999),
        sessionKept: (state.sessionKept - 1).clamp(0, 99999),
      );
    }

    _updateActivity(isUndo: true);
    state = state.copyWith(
      photos: [lastUndo.photo, ...state.photos],
      undoStack: state.undoStack.sublist(0, state.undoStack.length - 1),
    );
    await _persistStats();
  }

  Future<void> restoreSpecific(File file) async {
    final fileName = p.basename(file.path);
    final originalPath = state.trashPathMap[fileName];
    if (originalPath != null) {
      final success = await _fileService.restoreFromTrash(fileName, originalPath);
      if (success) {
        final newTrashMap = Map<String, String>.from(state.trashPathMap)..remove(fileName);
        await _saveTrashMap(newTrashMap);
        _updateActivity(isUndo: true);
        state = state.copyWith(
          lifetimeTrashed: (state.lifetimeTrashed - 1).clamp(0, 9999999),
          trashPathMap: newTrashMap,
        );
        await _persistStats();
      }
    }
  }

  Future<void> deleteSpecific(File file) async {
    final sizeMb = (await file.length()) / (1024 * 1024);
    final fileName = p.basename(file.path);
    if (await file.exists()) {
      await file.delete();
      final newTrashMap = Map<String, String>.from(state.trashPathMap)..remove(fileName);
      await _saveTrashMap(newTrashMap);
      state = state.copyWith(
        lifetimeSpaceReleased: state.lifetimeSpaceReleased + sizeMb,
        trashPathMap: newTrashMap,
      );
      await _persistStats();
    }
  }

  void _updateActivity({bool isUndo = false}) {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final currentVal = state.weeklyActivity[today] ?? 0;
    final newVal = isUndo ? (currentVal - 1).clamp(0, 99999) : currentVal + 1;
    
    final newActivity = {...state.weeklyActivity, today: newVal};
    state = state.copyWith(weeklyActivity: newActivity);
  }

  Future<void> clearTrash() async {
    final trashFiles = await _fileService.getTrashFiles();
    double totalSizeMb = 0;
    for (var f in trashFiles) {
      if (await f.exists()) {
        totalSizeMb += (await f.length()) / (1024 * 1024);
      }
    }

    await _fileService.clearAppTrash();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTrashPathMapKey);

    state = state.copyWith(
      lifetimeSpaceReleased: state.lifetimeSpaceReleased + totalSizeMb,
      trashPathMap: {},
    );
    await _persistStats();
  }

  Future<void> _persistStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLifetimeKept, state.lifetimeKept);
    await prefs.setInt(_kLifetimeTrashed, state.lifetimeTrashed);
    await prefs.setDouble(_kLifetimeSpace, state.lifetimeSpaceReleased);
    await prefs.setString(_kWeeklyActivity, json.encode(state.weeklyActivity));
  }

  Future<void> _saveTrashMap(Map<String, String> map) async {
    final prefs = await SharedPreferences.getInstance();
    final list = map.entries.map((e) => '${e.key}|${e.value}').toList();
    await prefs.setStringList(_kTrashPathMapKey, list);
  }
}

final photoProvider = StateNotifierProvider<PhotoNotifier, PhotoState>((ref) => PhotoNotifier());
