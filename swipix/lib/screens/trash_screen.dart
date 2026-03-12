import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/file_service.dart';
import '../providers/photo_provider.dart';
import '../core/theme.dart';
import '../widgets/animated_aurora.dart';
import 'photo_view_screen.dart';

class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  final FileService _fileService = FileService();
  List<File> _trashFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrash();
  }

  Future<void> _loadTrash() async {
    final files = await _fileService.getTrashFiles();
    if (mounted) {
      setState(() {
        _trashFiles = files;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('VAULT', style: GoogleFonts.plusJakartaSans(letterSpacing: 4, fontWeight: FontWeight.w900, color: Colors.white)),
        actions: [
          if (_trashFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton(
                onPressed: () => _confirmClear(),
                child: const Text('PURGE ALL', style: TextStyle(color: AppTheme.bloodRed, fontWeight: FontWeight.w900)),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          const AnimatedAurora(),
          _isLoading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 1, color: AppTheme.electricViolet))
              : _trashFiles.isEmpty
                  ? Center(
                      child: Text(
                        'VAULT IS EMPTY',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withOpacity(0.2),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 120, 16, 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _trashFiles.length,
                      itemBuilder: (context, index) {
                        final file = _trashFiles[index];
                        return GestureDetector(
                          onTap: () => _showOptions(file),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.file(
                              file,
                              fit: BoxFit.cover,
                              cacheWidth: 300,
                              cacheHeight: 300,
                            ),
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }

  void _showOptions(File file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A0A0B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OptionTile(
              icon: Icons.fullscreen_rounded,
              label: 'VIEW FULLSCREEN',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => PhotoViewScreen(file: file)));
              },
            ),
            const SizedBox(height: 16),
            _OptionTile(
              icon: Icons.settings_backup_restore_rounded,
              label: 'RESTORE TO GALLERY',
              color: AppTheme.toxicGreen,
              onTap: () async {
                await ref.read(photoProvider.notifier).restoreSpecific(file);
                await _loadTrash();
                if (mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
            _OptionTile(
              icon: Icons.delete_forever_rounded,
              label: 'DELETE PERMANENTLY',
              color: AppTheme.bloodRed,
              onTap: () async {
                await file.delete();
                await _loadTrash();
                if (mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF0A0A0B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          title: const Text('PURGE VAULT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
          content: const Text('All items will be permanently destroyed.', style: TextStyle(color: Colors.white60)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.bloodRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () async {
                await ref.read(photoProvider.notifier).clearTrash();
                await _loadTrash();
                if (mounted) Navigator.pop(context);
              },
              child: const Text('ERASE FOREVER', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _OptionTile({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color ?? Colors.white70),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(color: color ?? Colors.white, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}
