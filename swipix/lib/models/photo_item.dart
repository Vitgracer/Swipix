import 'package:photo_manager/photo_manager.dart';

class PhotoItem {
  final AssetEntity asset;
  final String id;
  String? originalPath; // Сохраняем путь для восстановления

  PhotoItem({
    required this.asset,
    this.originalPath,
  }) : id = asset.id;
}
