import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';

class PhotoService {
  Future<bool> requestPermissions() async {
    // Android 11+ needs MANAGE_EXTERNAL_STORAGE for "silent" move/delete actions
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
    }

    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    return ps.isAuth;
  }

  Future<List<AssetPathEntity>> getAlbums() async {
    return await PhotoManager.getAssetPathList(
      type: RequestType.image,
      filterOption: FilterOptionGroup(
        imageOption: const FilterOption(
          sizeConstraint: SizeConstraint(ignoreSize: true),
        ),
      ),
    );
  }

  Future<List<AssetEntity>> getPhotosFromAlbum(AssetPathEntity album) async {
    final int assetCount = await album.assetCountAsync;
    return await album.getAssetListRange(start: 0, end: assetCount);
  }
}
