import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import '../models/photo_item.dart';
import '../services/photo_service.dart';
import '../services/file_service.dart';
import '../services/photo_metadata_service.dart';

enum SwipeAction { keep, trash }
enum SmartFilter { none, thisDay, monthly, unknown }

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
  final SmartFilter currentFilter;
  final int selectedSmartMonth; 
  final int selectedSmartYear; 
  final bool isLoading;
  final bool isProcessing;
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
  
  final int currentPage;
  final bool hasMore;
  final int totalPhotosInAlbum;

  PhotoState({
    this.photos = const [],
    this.albums = const [],
    this.selectedAlbum,
    this.currentFilter = SmartFilter.none,
    this.selectedSmartMonth = 0,
    this.selectedSmartYear = 0,
    this.isLoading = false,
    this.isProcessing = false,
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
    this.currentPage = 0,
    this.hasMore = true,
    this.totalPhotosInAlbum = 0,
  });

  PhotoState copyWith({
    List<PhotoItem>? photos,
    List<AssetPathEntity>? albums,
    AssetPathEntity? selectedAlbum,
    bool clearSelectedAlbum = false, 
    SmartFilter? currentFilter,
    int? selectedSmartMonth,
    int? selectedSmartYear,
    bool? isLoading,
    bool? isProcessing,
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
    int? currentPage,
    bool? hasMore,
    int? totalPhotosInAlbum,
  }) {
    return PhotoState(
      photos: photos ?? this.photos,
      albums: albums ?? this.albums,
      selectedAlbum: clearSelectedAlbum ? null : (selectedAlbum ?? this.selectedAlbum),
      currentFilter: currentFilter ?? this.currentFilter,
      selectedSmartMonth: selectedSmartMonth ?? this.selectedSmartMonth,
      selectedSmartYear: selectedSmartYear ?? this.selectedSmartYear,
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
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
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      totalPhotosInAlbum: totalPhotosInAlbum ?? this.totalPhotosInAlbum,
    );
  }
}

class PhotoNotifier extends StateNotifier<PhotoState> {
  final PhotoService _photoService = PhotoService();
  final FileService _fileService = FileService();
  final PhotoMetadataService _metadataService = PhotoMetadataService();
  
  static const String _kKeptKey = 'kept_photo_ids';
  static const String _kTrashPathMapKey = 'trash_path_map_v2'; 
  static const String _kLifetimeKept = 'lifetime_kept';
  static const String _kLifetimeTrashed = 'lifetime_trashed';
  static const String _kLifetimeSpace = 'lifetime_space_released';
  static const String _kWeeklyActivity = 'weekly_activity';
  static const int _pageSize = 300;

  Timer? _saveTimer;

  PhotoNotifier() : super(PhotoState(
    selectedSmartMonth: DateTime.now().month,
    selectedSmartYear: DateTime.now().year,
  )) {
    init();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  Future<void> init() async {
    try {
      state = state.copyWith(isLoading: true);
      final prefs = await SharedPreferences.getInstance();
      
      final keptList = prefs.getStringList(_kKeptKey) ?? [];
      
      Map<String, String> trashMap = {};
      final trashJson = prefs.getString(_kTrashPathMapKey);
      if (trashJson != null) {
        try {
          trashMap = Map<String, String>.from(json.decode(trashJson));
        } catch (e) {
          debugPrint('Error decoding trash map JSON: $e');
        }
      }

      final lKept = prefs.getInt(_kLifetimeKept) ?? 0;
      final lTrashed = prefs.getInt(_kLifetimeTrashed) ?? 0;
      final lSpace = prefs.getDouble(_kLifetimeSpace) ?? 0.0;
      final weeklyRaw = prefs.getString(_kWeeklyActivity) ?? '{}';
      
      Map<String, int> weekly = {};
      try {
        final decoded = json.decode(weeklyRaw);
        if (decoded is Map) {
          weekly = decoded.map((k, v) => MapEntry(k.toString(), v as int));
        }
      } catch (e) {
        debugPrint('Error decoding weekly activity: $e');
      }
      
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
    } catch (e) {
      debugPrint('Initialization error: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<int> getRemainingCount(AssetPathEntity album) async {
    try {
      final totalCount = await album.assetCountAsync;
      if (totalCount == 0) return 0;
      final assets = await album.getAssetListRange(start: 0, end: totalCount);
      return assets.where((a) => !state.globalKeptIds.contains(a.id)).length;
    } catch (e) {
      debugPrint('Error getting remaining count: $e');
      return 0;
    }
  }

  /// NEW: Get the range of years based on reliable photo dates
  Future<List<int>> getYearRange() async {
    try {
      final albums = await _photoService.getAlbums();
      if (albums.isEmpty) return [DateTime.now().year];
      
      final allAlbum = albums.first;
      final totalCount = await allAlbum.assetCountAsync;
      if (totalCount == 0) return [DateTime.now().year];

      final allAssets = await allAlbum.getAssetListRange(start: 0, end: totalCount);
      
      Set<int> years = {DateTime.now().year};
      for (var asset in allAssets) {
        if (state.globalKeptIds.contains(asset.id)) continue;
        
        final result = _metadataService.getFastReliableDate(
          fileName: asset.title ?? '', 
          systemDate: asset.createDateTime
        );
        
        if (!result.isUnknown) {
          years.add(result.date.year);
        }
      }

      List<int> sortedYears = years.toList()..sort((a, b) => b.compareTo(a));
      return sortedYears;
    } catch (e) {
      debugPrint('Error getting year range: $e');
      return [DateTime.now().year];
    }
  }

  /// NEW: Accurate all-time stats using reliable dates
  Future<Map<int, Map<int, int>>> getAllTimeStats() async {
    try {
      final albums = await _photoService.getAlbums();
      if (albums.isEmpty) return {};
      
      final allAlbum = albums.first;
      final totalCount = await allAlbum.assetCountAsync;
      final allAssets = await allAlbum.getAssetListRange(start: 0, end: totalCount);
      
      Map<int, Map<int, int>> stats = {}; // year -> month -> count
      for (var asset in allAssets) {
        if (state.globalKeptIds.contains(asset.id)) continue;
        
        final result = _metadataService.getFastReliableDate(
          fileName: asset.title ?? '', 
          systemDate: asset.createDateTime
        );

        // We only count categorized photos in the time machine
        if (!result.isUnknown) {
          final year = result.date.year;
          final month = result.date.month;
          
          stats.putIfAbsent(year, () => {});
          stats[year]![month] = (stats[year]![month] ?? 0) + 1;
        }
      }
      return stats;
    } catch (e) {
      debugPrint('Error getting all time stats: $e');
      return {};
    }
  }

  Future<void> selectAlbum(AssetPathEntity album) async {
    if (state.isProcessing) return;
    try {
      state = state.copyWith(
        isLoading: true, 
        selectedAlbum: album, 
        currentFilter: SmartFilter.none, 
        photos: [], 
        undoStack: [],
        sessionKept: 0,
        sessionTrashed: 0,
        currentPage: 0,
        hasMore: true,
      );
      
      final totalInAlbum = await getRemainingCount(album);
      state = state.copyWith(totalPhotosInAlbum: totalInAlbum);
      
      await _loadNextPage();
    } catch (e) {
      debugPrint('Album selection error: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> selectSmartFilter(SmartFilter filter, {int? month, int? year}) async {
    if (state.isProcessing) return;
    try {
      final targetMonth = month ?? state.selectedSmartMonth;
      final targetYear = year ?? state.selectedSmartYear;
      
      state = state.copyWith(
        isLoading: true, 
        currentFilter: filter, 
        selectedSmartMonth: targetMonth,
        selectedSmartYear: targetYear,
        clearSelectedAlbum: true,
        photos: [], 
        undoStack: [],
        sessionKept: 0,
        sessionTrashed: 0,
        totalPhotosInAlbum: 0,
      );

      final now = DateTime.now();
      final albums = await _photoService.getAlbums();
      if (albums.isEmpty) {
         state = state.copyWith(isLoading: false, hasMore: false);
         return;
      }
      
      final allAlbum = albums.first;
      final totalCount = await allAlbum.assetCountAsync;
      final allAssets = await allAlbum.getAssetListRange(start: 0, end: totalCount);
      
      List<PhotoItem> filtered = [];
      
      for (var asset in allAssets) {
        if (state.globalKeptIds.contains(asset.id)) continue;
        
        final result = _metadataService.getFastReliableDate(
          fileName: asset.title ?? '', 
          systemDate: asset.createDateTime
        );
        
        if (filter == SmartFilter.unknown) {
          if (result.isUnknown) {
            filtered.add(PhotoItem(asset: asset, date: result.date, isDateUnknown: true));
          }
          continue;
        }

        if (result.isUnknown) continue;

        bool actuallyMatches = false;
        if (filter == SmartFilter.thisDay) {
          actuallyMatches = (result.date.day == now.day && result.date.month == now.month);
        } else if (filter == SmartFilter.monthly) {
          actuallyMatches = (result.date.month == targetMonth && result.date.year == targetYear);
        }

        if (actuallyMatches) {
          filtered.add(PhotoItem(asset: asset, date: result.date, isDateUnknown: false));
        }
      }

      state = state.copyWith(
        photos: filtered,
        isLoading: false,
        hasMore: false,
        totalPhotosInAlbum: filtered.length,
      );
    } catch (e) {
      debugPrint('Smart filter selection error: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _loadNextPage() async {
    if (!state.hasMore || state.selectedAlbum == null) {
      state = state.copyWith(isLoading: false);
      return;
    }
    
    final assets = await _photoService.getPhotosFromAlbum(
      state.selectedAlbum!, 
      page: state.currentPage, 
      size: _pageSize
    );

    if (assets.isEmpty) {
      state = state.copyWith(hasMore: false, isLoading: false);
      return;
    }

    List<PhotoItem> newPhotos = [];
    for (var a in assets) {
      if (!state.globalKeptIds.contains(a.id)) {
        final result = _metadataService.getFastReliableDate(
          fileName: a.title ?? '', 
          systemDate: a.createDateTime
        );
        newPhotos.add(PhotoItem(asset: a, date: result.date, isDateUnknown: result.isUnknown));
      }
    }

    state = state.copyWith(
      photos: [...state.photos, ...newPhotos],
      currentPage: state.currentPage + 1,
      isLoading: false,
      hasMore: assets.length == _pageSize,
    );
    
    if (state.photos.length < 15 && state.hasMore) {
      await _loadNextPage();
    }
  }

  Future<void> swipeLeft(PhotoItem photo) async {
    if (state.isProcessing) return;
    state = state.copyWith(isProcessing: true);
    
    try {
      final file = await photo.asset.file;
      if (file == null || !await file.exists()) {
        state = state.copyWith(
          isProcessing: false, 
          photos: state.photos.where((p) => p.id != photo.id).toList()
        );
        return;
      }

      final sizeMb = (await file.length()) / (1024 * 1024);
      final originalPath = file.path;
      
      final uniqueTrashName = await _fileService.forceMoveToTrash(file);
      
      if (uniqueTrashName != null) {
        final newTrashMap = {...state.trashPathMap, uniqueTrashName: originalPath};
        _saveTrashMap(newTrashMap); 
        _updateActivity();

        state = state.copyWith(
          photos: state.photos.where((p) => p.id != photo.id).toList(),
          undoStack: [...state.undoStack, UndoItem(photo: photo, action: SwipeAction.trash, trashFileName: uniqueTrashName, sizeMb: sizeMb)],
          trashPathMap: newTrashMap,
          lifetimeTrashed: state.lifetimeTrashed + 1,
          sessionTrashed: state.sessionTrashed + 1,
          isProcessing: false,
        );
        
        if (state.photos.length < 15 && state.hasMore) {
           _loadNextPage();
        }
        
        _scheduleStatsPersistence();
      } else {
        state = state.copyWith(isProcessing: false);
      }
    } catch (e) {
      debugPrint('Swipe left error: $e');
      state = state.copyWith(isProcessing: false);
    }
  }

  Future<void> swipeRight(PhotoItem photo) async {
    if (state.isProcessing) return;
    state = state.copyWith(isProcessing: true);

    try {
      final newKeptIds = {...state.globalKeptIds, photo.id};
      _updateActivity();

      state = state.copyWith(
        photos: state.photos.where((p) => p.id != photo.id).toList(),
        globalKeptIds: newKeptIds,
        undoStack: [...state.undoStack, UndoItem(photo: photo, action: SwipeAction.keep, sizeMb: 0)],
        lifetimeKept: state.lifetimeKept + 1,
        sessionKept: state.sessionKept + 1,
        isProcessing: false,
      );
      
      if (state.photos.length < 15 && state.hasMore) {
        _loadNextPage();
      }
      
      _scheduleStatsPersistence();
    } catch (e) {
      debugPrint('Swipe right error: $e');
      state = state.copyWith(isProcessing: false);
    }
  }

  Future<void> undo() async {
    if (state.undoStack.isEmpty || state.isProcessing) return;
    state = state.copyWith(isProcessing: true);

    try {
      final lastUndo = state.undoStack.last;
      
      if (lastUndo.action == SwipeAction.trash && lastUndo.trashFileName != null) {
        final originalPath = state.trashPathMap[lastUndo.trashFileName!];
        if (originalPath != null) {
          final success = await _fileService.restoreFromTrash(lastUndo.trashFileName!, originalPath);
          if (success) {
             final newTrashMap = Map<String, String>.from(state.trashPathMap)..remove(lastUndo.trashFileName!);
             _saveTrashMap(newTrashMap);
             
             state = state.copyWith(
               trashPathMap: newTrashMap,
               lifetimeTrashed: (state.lifetimeTrashed - 1).clamp(0, 9999999),
               sessionTrashed: (state.sessionTrashed - 1).clamp(0, 99999),
             );
          } else { 
            state = state.copyWith(isProcessing: false);
            return; 
          }
        }
      } else if (lastUndo.action == SwipeAction.keep) {
        final newKeptIds = state.globalKeptIds.where((id) => id != lastUndo.photo.id).toSet();
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
        isProcessing: false,
      );
      _scheduleStatsPersistence();
    } catch (e) {
      debugPrint('Undo error: $e');
      state = state.copyWith(isProcessing: false);
    }
  }

  void _scheduleStatsPersistence() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () => _persistStats());
  }

  Future<void> _persistStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLifetimeKept, state.lifetimeKept);
      await prefs.setInt(_kLifetimeTrashed, state.lifetimeTrashed);
      await prefs.setDouble(_kLifetimeSpace, state.lifetimeSpaceReleased);
      await prefs.setString(_kWeeklyActivity, json.encode(state.weeklyActivity));
      await prefs.setStringList(_kKeptKey, state.globalKeptIds.toList());
    } catch (e) {
      debugPrint('Persist stats error: $e');
    }
  }

  Future<void> _saveTrashMap(Map<String, String> map) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTrashPathMapKey, json.encode(map));
    } catch (e) {
      debugPrint('Save trash map error: $e');
    }
  }

  Future<void> clearTrash() async {
    if (state.isProcessing) return;
    state = state.copyWith(isProcessing: true);

    try {
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
        undoStack: [],
        isProcessing: false,
      );
      _scheduleStatsPersistence();
    } catch (e) {
      debugPrint('Clear trash error: $e');
      state = state.copyWith(isProcessing: false);
    }
  }

  void _updateActivity({bool isUndo = false}) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final currentVal = state.weeklyActivity[today] ?? 0;
    final newVal = isUndo ? (currentVal - 1).clamp(0, 99999) : currentVal + 1;
    
    final Map<String, int> newActivity = {...state.weeklyActivity, today: newVal};
    state = state.copyWith(weeklyActivity: newActivity);
  }

  Future<void> restoreSpecific(File file) async {
    if (state.isProcessing) return;
    state = state.copyWith(isProcessing: true);

    try {
      final fileName = p.basename(file.path);
      final originalPath = state.trashPathMap[fileName];
      if (originalPath != null) {
        final success = await _fileService.restoreFromTrash(fileName, originalPath);
        if (success) {
          final newTrashMap = Map<String, String>.from(state.trashPathMap)..remove(fileName);
          _saveTrashMap(newTrashMap);
          _updateActivity(isUndo: true);
          
          int newTotal = state.totalPhotosInAlbum;
          if (state.selectedAlbum != null && originalPath.contains(state.selectedAlbum!.name)) {
             newTotal++;
          }

          state = state.copyWith(
            lifetimeTrashed: (state.lifetimeTrashed - 1).clamp(0, 9999999),
            trashPathMap: newTrashMap,
            undoStack: [],
            totalPhotosInAlbum: newTotal,
            isProcessing: false,
          );
          _scheduleStatsPersistence();
        } else {
          state = state.copyWith(isProcessing: false);
        }
      } else {
        state = state.copyWith(isProcessing: false);
      }
    } catch (e) {
      debugPrint('Restore specific error: $e');
      state = state.copyWith(isProcessing: false);
    }
  }

  Future<void> deleteSpecific(File file) async {
    if (state.isProcessing) return;
    state = state.copyWith(isProcessing: true);

    try {
      if (await file.exists()) {
        final sizeMb = (await file.length()) / (1024 * 1024);
        final fileName = p.basename(file.path);
        await file.delete();
        final newTrashMap = Map<String, String>.from(state.trashPathMap)..remove(fileName);
        _saveTrashMap(newTrashMap);
        state = state.copyWith(
          lifetimeSpaceReleased: state.lifetimeSpaceReleased + sizeMb,
          trashPathMap: newTrashMap,
          undoStack: [],
          isProcessing: false,
        );
        _scheduleStatsPersistence();
      } else {
        state = state.copyWith(isProcessing: false);
      }
    } catch (e) {
      debugPrint('Delete specific error: $e');
      state = state.copyWith(isProcessing: false);
    }
  }
}

final photoProvider = StateNotifierProvider<PhotoNotifier, PhotoState>((ref) => PhotoNotifier());
