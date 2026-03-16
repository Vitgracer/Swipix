import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/photo_provider.dart';
import '../core/theme.dart';
import '../widgets/animated_aurora.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  int _focusedYear = DateTime.now().year;
  Map<int, int> _monthlyStats = {};
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoadingStats = true);
    final stats = await ref.read(photoProvider.notifier).getMonthlyStats(_focusedYear);
    if (mounted) {
      setState(() {
        _monthlyStats = stats;
        _isLoadingStats = false;
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
          'TIME MACHINE',
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
            child: Column(
              children: [
                _buildYearSelector(),
                Expanded(
                  child: _isLoadingStats 
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.electricViolet))
                    : _buildMonthGrid(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearSelector() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: DateTime.now().year - 2014, // Show years from 2015
        reverse: true,
        itemBuilder: (context, index) {
          final year = DateTime.now().year - index;
          final isSelected = _focusedYear == year;
          return GestureDetector(
            onTap: () {
              setState(() => _focusedYear = year);
              _loadStats();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.electricViolet : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppTheme.electricViolet : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Text(
                '$year',
                style: GoogleFonts.plusJakartaSans(
                  color: isSelected ? Colors.white : Colors.white38,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonthGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        final month = index + 1;
        final count = _monthlyStats[month] ?? 0;
        final isFuture = _focusedYear == DateTime.now().year && month > DateTime.now().month;
        
        return _buildMonthCard(month, count, isFuture);
      },
    );
  }

  Widget _buildMonthCard(int month, int count, bool isFuture) {
    final bool isCleaned = count == 0 && !isFuture;
    final String monthName = DateFormat('MMM').format(DateTime(2024, month)).toUpperCase();

    return GestureDetector(
      onTap: (!isFuture && count > 0) ? () {
        ref.read(photoProvider.notifier).selectSmartFilter(SmartFilter.monthly, month: month, year: _focusedYear);
        Navigator.pop(context); // Close calendar
        Navigator.pop(context); // Return to swipe screen
      } : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: isCleaned 
                  ? AppTheme.toxicGreen.withOpacity(0.1) 
                  : isFuture ? Colors.white.withOpacity(0.01) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isCleaned ? AppTheme.toxicGreen.withOpacity(0.3) : Colors.white.withOpacity(0.05),
              ),
              gradient: isCleaned ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.toxicGreen.withOpacity(0.2), AppTheme.electricViolet.withOpacity(0.1)],
              ) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  monthName,
                  style: GoogleFonts.plusJakartaSans(
                    color: isFuture ? Colors.white10 : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                if (isCleaned)
                  const Text(
                    'CLEANED ✨',
                    style: TextStyle(color: AppTheme.toxicGreen, fontWeight: FontWeight.w900, fontSize: 8, letterSpacing: 1),
                  )
                else if (isFuture)
                  const Icon(Icons.lock_clock_outlined, color: Colors.white10, size: 16)
                else
                  Text(
                    '$count PHOTOS',
                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontWeight: FontWeight.bold, fontSize: 9),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
