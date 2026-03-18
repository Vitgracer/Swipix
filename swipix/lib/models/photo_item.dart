import 'package:photo_manager/photo_manager.dart';

class PhotoItem {
  final AssetEntity asset;
  final String id;
  final DateTime date; 
  final bool isDateUnknown; // New flag to track if the date is unreliable
  String? originalPath; 

  PhotoItem({
    required this.asset,
    required this.date,
    this.isDateUnknown = false,
    this.originalPath,
  }) : id = asset.id;
}
