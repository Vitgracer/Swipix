import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/photo_provider.dart';
import '../services/file_service.dart';
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
  bool _isLoading = true;
  List<File> _trashFiles = [];

  @override
  void initState() {
    super.initState();
    _loadTrash();
  }

  Future<void> _loadTrash() async {
    // Only show full loading indicator on first load
    if (_trashFiles.isEmpty) setState(() => _isLoading = true);
    
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
        title: Text(
          'TRASH BIN',
          style: GoogleFonts.plusJakartaSans(
            letterSpacing: 4,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        actions: [
          if (_trashFiles.isNotEmpty)
            TextButton(
              onPressed: () => _showDeleteConfirmation(context),
              child: const Text('EMPTY', style: TextStyle(color: AppTheme.bloodRed, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ),
        ],
      ),
      body: Stack(
        children: [
          const AnimatedAurora(),
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.electricViolet))
              : _trashFiles.isEmpty
                  ? _buildEmptyState()
                  : _buildTrashGrid(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_delete_rounded, size: 80, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 24),
          const Text(
            'TRASH IS EMPTY',
            style: TextStyle(color: Colors.white24, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
        ],
      ),
    );
  }

  Widget _buildTrashGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 120, 20, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _trashFiles.length,
      itemBuilder: (context, index) {
        final file = _trashFiles[index];
        return GestureDetector(
          onTap: () => _showFileOptions(context, file),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              image: DecorationImage(
                // Use ResizeImage to load thumbnails instead of full-res photos
                // This drastically improves performance and reduces memory usage
                image: ResizeImage(
                  FileImage(file),
                  width: 300, 
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFileOptions(BuildContext context, File file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 32),
            _OptionTile(
              icon: Icons.visibility_rounded,
              title: 'VIEW PHOTO',
              color: Colors.white,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => PhotoViewScreen(file: file)));
              },
            ),
            const SizedBox(height: 12),
            _OptionTile(
              icon: Icons.restore_rounded,
              title: 'RESTORE PHOTO',
              color: AppTheme.toxicGreen,
              onTap: () async {
                Navigator.pop(context);
                await ref.read(photoProvider.notifier).restoreSpecific(file);
                _loadTrash();
              },
            ),
            const SizedBox(height: 12),
            _OptionTile(
              icon: Icons.delete_forever_rounded,
              title: 'DELETE PERMANENTLY',
              color: AppTheme.bloodRed,
              onTap: () async {
                Navigator.pop(context);
                await ref.read(photoProvider.notifier).deleteSpecific(file);
                _loadTrash();
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('PURGE TRASH?', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        content: const Text('This will permanently delete all photos in the app trash and free up storage.', style: TextStyle(color: Colors.white60)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog first
              setState(() => _isLoading = true); // Show loading
              await ref.read(photoProvider.notifier).clearTrash();
              await _loadTrash(); // Refresh list
            },
            child: const Text('PURGE', style: TextStyle(color: AppTheme.bloodRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({required this.icon, required this.title, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 13),
      ),
      tileColor: color.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
