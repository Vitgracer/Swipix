import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class FileService {
  static const String trashFolderName = '.swipix_trash';

  Future<String> get _trashPath async {
    final directory = await getExternalStorageDirectory();
    final path = p.join(directory!.path, trashFolderName);
    final trashDir = Directory(path);
    if (!await trashDir.exists()) {
      await trashDir.create(recursive: true);
      final nomedia = File(p.join(path, '.nomedia'));
      if (!await nomedia.exists()) await nomedia.create();
    }
    return path;
  }

  // Возвращаем новое имя файла в корзине для маппинга
  Future<String?> forceMoveToTrash(File originalFile) async {
    try {
      final trashDir = await _trashPath;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueName = '${timestamp}_${p.basename(originalFile.path)}';
      final targetPath = p.join(trashDir, uniqueName);
      
      print('DEBUG: Moving ${originalFile.path} to $targetPath');
      
      await originalFile.copy(targetPath);
      if (await originalFile.exists()) {
        await originalFile.delete();
        print('DEBUG: Original deleted successfully');
        return uniqueName;
      }
      return null;
    } catch (e) {
      print('ERROR in forceMoveToTrash: $e');
      return null;
    }
  }

  Future<bool> restoreFromTrash(String trashFileName, String originalPath) async {
    try {
      final trashDir = await _trashPath;
      final trashFile = File(p.join(trashDir, trashFileName));
      
      if (!await trashFile.exists()) {
        print('ERROR: Trash file not found: $trashFileName');
        return false;
      }

      print('DEBUG: Restoring $trashFileName to $originalPath');
      
      final targetDir = Directory(p.dirname(originalPath));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      
      await trashFile.copy(originalPath);
      await trashFile.delete();
      print('DEBUG: Restoration complete');
      return true;
    } catch (e) {
      print('ERROR in restoreFromTrash: $e');
      return false;
    }
  }

  Future<List<File>> getTrashFiles() async {
    final trashDir = Directory(await _trashPath);
    if (await trashDir.exists()) {
      return trashDir
          .listSync()
          .whereType<File>()
          .where((f) => !p.basename(f.path).startsWith('.'))
          .toList();
    }
    return [];
  }

  Future<void> clearAppTrash() async {
    final trashDir = Directory(await _trashPath);
    if (await trashDir.exists()) {
      final files = trashDir.listSync();
      for (var file in files) {
        if (file is File && !p.basename(file.path).startsWith('.')) {
          await file.delete();
        }
      }
    }
  }
}
