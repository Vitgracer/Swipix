import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/photo_item.dart';
import '../screens/photo_view_screen.dart';
import '../core/theme.dart';

class PhotoCard extends StatefulWidget {
  final PhotoItem photo;

  const PhotoCard({super.key, required this.photo});

  @override
  State<PhotoCard> createState() => _PhotoCardState();
}

class _PhotoCardState extends State<PhotoCard> {
  Uint8List? _cachedBytes;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    final bytes = await widget.photo.asset.thumbnailDataWithSize(
      const ThumbnailSize(600, 1000),
    );
    if (mounted) {
      setState(() => _cachedBytes = bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, __, ___) => PhotoViewScreen(asset: widget.photo.asset),
          transitionsBuilder: (context, anim, __, child) => FadeTransition(
            opacity: anim,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20 * anim.value, sigmaY: 20 * anim.value),
              child: child,
            ),
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: const Color(0xFF0F0F10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_cachedBytes != null)
              Image.memory(
                _cachedBytes!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheWidth: 800,
              )
            else
              const Center(child: CircularProgressIndicator(strokeWidth: 1, color: Colors.white24)),
            
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.7, 1.0],
                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                  ),
                ),
              ),
            ),

            // Compact Elegant Info Bar
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: _CompactInfoBar(photo: widget.photo),
            ),

            // Date Overlay (Top Right)
            Positioned(
              top: 30,
              right: 30,
              child: _GlassDate(date: widget.photo.asset.createDateTime),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactInfoBar extends StatelessWidget {
  final PhotoItem photo;
  const _CompactInfoBar({required this.photo});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.photo_size_select_actual_outlined, color: Colors.white70, size: 14),
              const SizedBox(width: 8),
              Text(
                '${photo.asset.width}x${photo.asset.height}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              Container(width: 1, height: 12, color: Colors.white24),
              const SizedBox(width: 12),
              const Icon(Icons.sd_storage_outlined, color: AppTheme.electricViolet, size: 14),
              const SizedBox(width: 6),
              FutureBuilder<int>(
                future: photo.asset.file.then((f) => f?.length() ?? Future.value(0)),
                builder: (context, snapshot) {
                  final mb = ((snapshot.data ?? 0) / (1024 * 1024)).toStringAsFixed(1);
                  return Text(
                    '$mb MB',
                    style: const TextStyle(color: AppTheme.electricViolet, fontSize: 12, fontWeight: FontWeight.w900),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassDate extends StatelessWidget {
  final DateTime date;
  const _GlassDate({required this.date});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${date.day}',
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, height: 1),
              ),
              Text(
                _getMonth(date.month),
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5),
              ),
              const SizedBox(height: 4),
              Text(
                '${date.year}',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getMonth(int m) => ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'][m - 1];
}
