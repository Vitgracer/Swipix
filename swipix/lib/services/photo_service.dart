import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class PhotoService {
  Future<bool> requestPermissions() async {
    // Note: MANAGE_EXTERNAL_STORAGE is very sensitive for Google Play.
    // Consider if you can achieve the same with MediaStore API if you plan to publish.
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        await Permission.manageExternalStorage.request();
      }
    }

    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    return ps.isAuth;
  }

  Future<List<AssetPathEntity>> getAlbums() async {
    try {
      return await PhotoManager.getAssetPathList(
        type: RequestType.image,
        filterOption: FilterOptionGroup(
          imageOption: const FilterOption(
            sizeConstraint: SizeConstraint(ignoreSize: true),
          ),
        ),
      );
    } catch (e) {
      print('Error getting albums: $e');
      return [];
    }
  }

  /// Load photos with pagination to avoid OOM on large galleries
  Future<List<AssetEntity>> getPhotosFromAlbum(AssetPathEntity album, {int page = 0, int size = 300}) async {
    try {
      final int assetCount = await album.assetCountAsync;
      if (assetCount == 0) return [];
      
      // Safety check for range
      int start = page * size;
      if (start >= assetCount) return [];
      
      int end = (page + 1) * size;
      if (end > assetCount) end = assetCount;

      return await album.getAssetListRange(start: start, end: end);
    } catch (e) {
      print('Error getting photos: $e');
      return [];
    }
  }
  
  /// Notify the system that a file was deleted or moved
  Future<void> deleteFromMediaStore(AssetEntity asset) async {
    try {
      // Since we manually move the file, we should tell PhotoManager to remove it from its index
      await PhotoManager.editor.deleteWithIds([asset.id]);
    } catch (e) {
      print('Error deleting from MediaStore: $e');
    }
  }
}
