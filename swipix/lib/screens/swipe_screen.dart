import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/photo_provider.dart';
import '../widgets/swipeable_card.dart';
import '../core/theme.dart';
import 'stats_screen.dart';
import 'folder_selection_screen.dart';
import 'trash_screen.dart';
import '../widgets/animated_aurora.dart';

class SwipeScreen extends ConsumerStatefulWidget {
  const SwipeScreen({super.key});

  @override
  ConsumerState<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends ConsumerState<SwipeScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(photoProvider);
    final notifier = ref.read(photoProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.black,
      body: Stack(
        children: [
          const AnimatedAurora(),
          
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                const SizedBox(height: 10),
                _buildProgress(state),
                Expanded(
                  child: state.photos.isEmpty && !state.isLoading
                    ? _buildEmptyState(context)
                    : Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Stack(
                          children: state.photos.asMap().entries.map((entry) {
                            // Render only top cards for performance
                            if (entry.key > 2) return const SizedBox.shrink();
                            return SwipeableCard(
                              key: ValueKey(entry.value.id),
                              photo: entry.value,
                              index: entry.key,
                              onSwipeLeft: () => notifier.swipeLeft(entry.value),
                              onSwipeRight: () => notifier.swipeRight(entry.value),
                            );
                          }).toList().reversed.toList(),
                        ),
                      ),
                ),
                _buildFloatingControls(context, state, notifier),
                const SizedBox(height: 20),
              ],
            ),
          ),
          if (state.isLoading)
             const Center(child: CircularProgressIndicator(color: AppTheme.electricViolet)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _GlassIconButton(
            icon: Icons.grid_view_rounded,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FolderSelectionScreen())),
          ),
          Column(
            children: [
              Text(
                'SWIPIX',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                  color: Colors.white,
                ),
              ),
              Container(
                height: 2,
                width: 30,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.electricViolet, AppTheme.toxicGreen]),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
          _GlassIconButton(
            icon: Icons.auto_graph_rounded,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress(PhotoState state) {
    final reviewed = state.sessionKept + state.sessionTrashed;
    // USE totalPhotosInAlbum for true progress
    final total = state.totalPhotosInAlbum > 0 ? state.totalPhotosInAlbum : state.photos.length;
    final progress = total > 0 ? reviewed / total : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'COLLECTION PROGRESS ',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              Text(
                '$reviewed / $total',
                style: const TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.w900, 
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 4, // Slightly thicker for better visibility
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.electricViolet, AppTheme.toxicGreen],
                      ),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.electricViolet.withOpacity(0.5), 
                          blurRadius: 8, 
                          spreadRadius: 1
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingControls(BuildContext context, PhotoState state, PhotoNotifier notifier) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CircleAction(
            icon: Icons.undo_rounded,
            color: Colors.white.withOpacity(0.2),
            iconColor: Colors.white,
            onPressed: state.undoStack.isEmpty ? null : () => notifier.undo(),
          ),
          const Spacer(),
          _CircleAction(
            icon: Icons.close_rounded,
            color: AppTheme.bloodRed.withOpacity(0.15),
            iconColor: AppTheme.bloodRed,
            isLarge: true,
            onPressed: state.photos.isEmpty ? null : () => notifier.swipeLeft(state.photos.first),
          ),
          const SizedBox(width: 16),
          _CircleAction(
            icon: Icons.favorite_rounded,
            color: AppTheme.toxicGreen.withOpacity(0.15),
            iconColor: AppTheme.toxicGreen,
            isLarge: true,
            onPressed: state.photos.isEmpty ? null : () => notifier.swipeRight(state.photos.first),
          ),
          const Spacer(),
          _CircleAction(
            icon: Icons.delete_sweep_rounded,
            color: Colors.white.withOpacity(0.2),
            iconColor: Colors.white,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrashScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 100, color: AppTheme.electricViolet),
          const SizedBox(height: 24),
          Text(
            'PERFECTION ACHIEVED',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          const Text('Your gallery is clean.', style: TextStyle(color: Colors.white24)),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _GlassIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 20),
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final bool isLarge;
  final VoidCallback? onPressed;

  const _CircleAction({
    required this.icon,
    required this.color,
    required this.iconColor,
    this.isLarge = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: isLarge ? 80 : 56,
        height: isLarge ? 80 : 56,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: iconColor.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            if (onPressed != null)
              BoxShadow(
                color: iconColor.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Icon(
          icon,
          color: onPressed == null ? Colors.white10 : iconColor,
          size: isLarge ? 32 : 24,
        ),
      ),
    );
  }
}
