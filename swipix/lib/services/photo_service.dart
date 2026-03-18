import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class PhotoService {
  Future<bool> requestPermissions() async {
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
          orders: [
            const OrderOption(type: OrderOptionType.createDate, asc: false),
          ],
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
  
  Future<void> deleteFromMediaStore(AssetEntity asset) async {
    try {
      await PhotoManager.editor.deleteWithIds([asset.id]);
    } catch (e) {
      print('Error deleting from MediaStore: $e');
    }
  }
}
