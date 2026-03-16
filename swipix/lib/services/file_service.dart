import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class FileService {
  static const String trashFolderName = '.swipix_trash';

  Future<String?> get _trashPath async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) return null;
      
      final path = p.join(directory.path, trashFolderName);
      final trashDir = Directory(path);
      if (!await trashDir.exists()) {
        await trashDir.create(recursive: true);
        final nomedia = File(p.join(path, '.nomedia'));
        if (!await nomedia.exists()) await nomedia.create();
      }
      return path;
    } catch (e) {
      print('Error getting trash path: $e');
      return null;
    }
  }

  /// Moves a file to the internal app trash.
  /// Returns the unique name in trash if successful, null otherwise.
  Future<String?> forceMoveToTrash(File originalFile) async {
    try {
      if (!await originalFile.exists()) {
        print('ERROR: Original file does not exist: ${originalFile.path}');
        return null;
      }

      final trashDir = await _trashPath;
      if (trashDir == null) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueName = '${timestamp}_${p.basename(originalFile.path)}';
      final targetPath = p.join(trashDir, uniqueName);
      
      // Safety: check if destination exists (unlikely with timestamp but still)
      if (await File(targetPath).exists()) {
        print('WARNING: Target path already exists, skipping move.');
        return null;
      }

      // Copy then delete is safer than rename across partitions
      await originalFile.copy(targetPath);
      
      // Verify copy before deleting original
      final copiedFile = File(targetPath);
      if (await copiedFile.exists() && await copiedFile.length() == await originalFile.length()) {
        await originalFile.delete();
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
      if (trashDir == null) return false;

      final trashFile = File(p.join(trashDir, trashFileName));
      
      if (!await trashFile.exists()) {
        print('ERROR: Trash file not found: $trashFileName');
        return false;
      }

      final targetDir = Directory(p.dirname(originalPath));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      
      // Restore file
      await trashFile.copy(originalPath);
      
      // Verify restoration
      if (await File(originalPath).exists()) {
        await trashFile.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('ERROR in restoreFromTrash: $e');
      return false;
    }
  }

  Future<List<File>> getTrashFiles() async {
    try {
      final path = await _trashPath;
      if (path == null) return [];
      
      final trashDir = Directory(path);
      if (await trashDir.exists()) {
        return trashDir
            .listSync()
            .whereType<File>()
            .where((f) => !p.basename(f.path).startsWith('.'))
            .toList();
      }
    } catch (e) {
      print('Error listing trash files: $e');
    }
    return [];
  }

  Future<void> clearAppTrash() async {
    try {
      final path = await _trashPath;
      if (path == null) return;
      
      final trashDir = Directory(path);
      if (await trashDir.exists()) {
        final files = trashDir.listSync();
        for (var file in files) {
          if (file is File && !p.basename(file.path).startsWith('.')) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      print('Error clearing trash: $e');
    }
  }
}
