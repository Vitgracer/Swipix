import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/photo_provider.dart';
import '../core/theme.dart';
import '../widgets/animated_aurora.dart';
import 'calendar_screen.dart';
import '../services/photo_metadata_service.dart';

class FolderSelectionScreen extends ConsumerWidget {
  const FolderSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(photoProvider);
    final notifier = ref.read(photoProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'COLLECTIONS',
          style: GoogleFonts.plusJakartaSans(
            letterSpacing: 4,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
      body: Stack(
        children: [
          const AnimatedAurora(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('SMART FILTERS'),
                  _buildSmartFilterItem(
                    'THIS DAY', 
                    'MEMORIES FROM TODAY', 
                    SmartFilter.thisDay,
                    Icons.auto_awesome_rounded,
                    AppTheme.toxicGreen,
                    context, 
                    notifier, 
                    state
                  ),
                  _buildMonthlyFilterItem(context, state),
                  
                  // UNCATEGORIZED is now always visible
                  _buildSmartFilterItem(
                    'UNCATEGORIZED', 
                    'PHOTOS WITH UNKNOWN DATE', 
                    SmartFilter.unknown,
                    Icons.help_outline_rounded,
                    Colors.orangeAccent,
                    context, 
                    notifier, 
                    state
                  ),
                  
                  const SizedBox(height: 32),

                  _buildSectionHeader('ALL'),
                  _buildFolderItem(
                    'RECENT', 
                    state.albums.isNotEmpty ? state.albums.first : null,
                    context,
                    notifier,
                    state,
                  ),
                  const SizedBox(height: 32),
                  
                  _buildSectionHeader('FOLDERS'),
                  if (state.albums.isEmpty)
                    const Text('NO FOLDERS FOUND', style: TextStyle(color: Colors.white24, fontSize: 12))
                  else
                    ...state.albums.skip(1).map((album) => _buildFolderItem(
                      album.name.toUpperCase(),
                      album,
                      context,
                      notifier,
                      state,
                    )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 16),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.electricViolet,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 1,
              color: AppTheme.electricViolet.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyFilterItem(BuildContext context, PhotoState state) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 20),
              ),
              title: Text(
                'MONTHLY REVIEW',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
              subtitle: const Text(
                'EXPLORE TIME MACHINE',
                style: TextStyle(color: AppTheme.electricViolet, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
              ),
              trailing: Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.1), size: 14),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen())),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmartFilterItem(
    String title, 
    String subtitle, 
    SmartFilter filter,
    IconData icon,
    Color activeColor,
    BuildContext context, 
    PhotoNotifier notifier, 
    PhotoState state
  ) {
    final isSelected = state.currentFilter == filter;
    
    return FutureBuilder<int>(
      future: _getSmartCount(notifier, filter),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        final hasContent = count > 0;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? activeColor.withOpacity(0.15) 
                      : Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected 
                        ? activeColor.withOpacity(0.4) 
                        : Colors.white.withOpacity(0.05),
                    width: 1.5,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? activeColor : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      icon,
                      color: (hasContent || isLoading) ? Colors.white : Colors.white24,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      color: (hasContent || isLoading) ? Colors.white : Colors.white.withOpacity(0.5),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                  subtitle: isLoading 
                    ? const Text('SCANNING...', style: TextStyle(color: Colors.white10, fontSize: 10))
                    : Text(
                        hasContent ? '$count $subtitle' : 'ALL CLEANED', // UPDATED
                        style: TextStyle(
                          color: hasContent ? activeColor : AppTheme.toxicGreen, // Green if cleaned
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle_rounded, color: activeColor, size: 20)
                      : Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.1), size: 14),
                  onTap: hasContent ? () {
                    notifier.selectSmartFilter(filter);
                    Navigator.pop(context);
                  } : null,
                ),
              ),
            ),
          ),
        );
      }
    );
  }

  Future<int> _getSmartCount(PhotoNotifier notifier, SmartFilter filter) async {
    final albums = notifier.state.albums;
    if (albums.isEmpty) return 0;
    
    final allAlbum = albums.first;
    final total = await allAlbum.assetCountAsync;
    final assets = await allAlbum.getAssetListRange(start: 0, end: total);
    
    final metadataService = PhotoMetadataService();
    final now = DateTime.now();
    
    int count = 0;
    for (var asset in assets) {
      if (notifier.state.globalKeptIds.contains(asset.id)) continue;
      
      final result = metadataService.getFastReliableDate(
        fileName: asset.title ?? '', 
        systemDate: asset.createDateTime
      );

      if (filter == SmartFilter.unknown) {
        if (result.isUnknown) count++;
      } else if (filter == SmartFilter.thisDay) {
        if (!result.isUnknown && result.date.day == now.day && result.date.month == now.month) {
          count++;
        }
      }
    }
    return count;
  }

  Widget _buildFolderItem(
    String title, 
    dynamic album, 
    BuildContext context, 
    PhotoNotifier notifier, 
    PhotoState state
  ) {
    final isSelected = album != null && state.selectedAlbum?.id == album.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: isSelected 
                  ? AppTheme.electricViolet.withOpacity(0.15) 
                  : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected 
                    ? AppTheme.electricViolet.withOpacity(0.4) 
                    : Colors.white.withOpacity(0.05),
                width: 1.5,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.electricViolet : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isSelected ? Icons.folder_special_rounded : Icons.folder_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
              subtitle: album != null 
                ? FutureBuilder<int>(
                    future: notifier.getRemainingCount(album),
                    builder: (context, snapshot) {
                      final remaining = snapshot.data ?? 0;
                      if (remaining == 0 && snapshot.connectionState == ConnectionState.done) {
                        return const Text(
                          'ALL CLEANED',
                          style: TextStyle(
                            color: AppTheme.toxicGreen,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 1,
                          ),
                        );
                      }
                      return Text(
                        '$remaining TO REVIEW',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      );
                    },
                  )
                : null,
              trailing: isSelected
                  ? const Icon(Icons.check_circle_rounded, color: AppTheme.toxicGreen, size: 20)
                  : Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.1), size: 14),
              onTap: album != null ? () {
                notifier.selectAlbum(album);
                Navigator.pop(context);
              } : null,
            ),
          ),
        ),
      ),
    );
  }
}
