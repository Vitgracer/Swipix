import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class FileService {
  static const String trashFolderName = '.swipix_trash';
  
  /// Whitelist of allowed extensions to prevent accidental deletion of system files
  static const List<String> allowedExtensions = ['.jpg', '.jpeg', '.png', '.heic', '.webp', '.gif', '.mp4', '.mov'];

  Future<String?> get _trashPath async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) return null;
      
      final path = p.join(directory.path, trashFolderName);
      final trashDir = Directory(path);
      if (!await trashDir.exists()) {
        await trashDir.create(recursive: true);
        // Create .nomedia to hide trash from other gallery apps
        final nomedia = File(p.join(path, '.nomedia'));
        if (!await nomedia.exists()) await nomedia.create();
      }
      return path;
    } catch (e) {
      return null;
    }
  }

  /// Safety check: is this file allowed to be processed?
  bool _isSafeFile(File file) {
    final ext = p.extension(file.path).toLowerCase();
    return allowedExtensions.contains(ext);
  }

  Future<String?> forceMoveToTrash(File originalFile) async {
    try {
      if (!await originalFile.exists()) return null;
      if (!_isSafeFile(originalFile)) {
        print('SECURITY BLOCK: Attempted to move non-media file: ${originalFile.path}');
        return null;
      }

      final trashDir = await _trashPath;
      if (trashDir == null) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueName = '${timestamp}_${p.basename(originalFile.path)}';
      final targetPath = p.join(trashDir, uniqueName);
      
      if (await File(targetPath).exists()) return null;

      // ATOMIC MOVE SIMULATION: Copy + Verify + Delete
      final copiedFile = await originalFile.copy(targetPath);
      
      final originalSize = await originalFile.length();
      final copiedSize = await copiedFile.length();

      // Only delete original if sizes match exactly
      if (copiedSize == originalSize && originalSize > 0) {
        await originalFile.delete();
        return uniqueName;
      } else {
        // Integrity fail: remove the partial copy
        if (await copiedFile.exists()) await copiedFile.delete();
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<bool> restoreFromTrash(String trashFileName, String originalPath) async {
    try {
      final trashDir = await _trashPath;
      if (trashDir == null) return false;

      final trashFile = File(p.join(trashDir, trashFileName));
      if (!await trashFile.exists()) return false;

      final targetDir = Directory(p.dirname(originalPath));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      
      final restoredFile = await trashFile.copy(originalPath);
      
      if (await restoredFile.exists() && await restoredFile.length() == await trashFile.length()) {
        await trashFile.delete();
        return true;
      }
      return false;
    } catch (e) {
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
            // Only list files that are in our allowed list and not hidden system files
            .where((f) => !p.basename(f.path).startsWith('.') && _isSafeFile(f))
            .toList();
      }
    } catch (e) {}
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
          // Double safety: only delete if it is a file, in our trash folder, and not a system file
          if (file is File && !p.basename(file.path).startsWith('.') && _isSafeFile(file)) {
            await file.delete();
          }
        }
      }
    } catch (e) {}
  }
}
