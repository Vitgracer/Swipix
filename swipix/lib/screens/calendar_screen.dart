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
  List<int> _years = [];
  Map<int, Map<int, int>> _allTimeStats = {}; // year -> month -> count
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final notifier = ref.read(photoProvider.notifier);
    final years = await notifier.getYearRange();
    final stats = await notifier.getAllTimeStats();
    
    if (mounted) {
      setState(() {
        _years = years;
        _allTimeStats = stats;
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
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'TIME MACHINE',
          style: GoogleFonts.plusJakartaSans(
            letterSpacing: 4,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ),
      body: Stack(
        children: [
          const AnimatedAurora(),
          _isLoading 
            ? const Center(child: CircularProgressIndicator(color: AppTheme.electricViolet))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 120, 20, 40),
                physics: const BouncingScrollPhysics(),
                itemCount: _years.length,
                itemBuilder: (context, index) => _buildYearSection(_years[index]),
              ),
        ],
      ),
    );
  }

  Widget _buildYearSection(int year) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 24, 8, 16),
          child: Row(
            children: [
              Text(
                '$year',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white.withOpacity(0.15), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, 
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.85,
          ),
          itemCount: 12,
          itemBuilder: (context, index) {
            final month = index + 1;
            final count = _allTimeStats[year]?[month] ?? 0;
            final isFuture = year == DateTime.now().year && month > DateTime.now().month;
            
            return _buildMonthTile(year, month, count, isFuture);
          },
        ),
      ],
    );
  }

  Widget _buildMonthTile(int year, int month, int count, bool isFuture) {
    final bool isCleaned = count == 0 && !isFuture;
    final String monthName = DateFormat('MMM').format(DateTime(2024, month)).toUpperCase();

    return GestureDetector(
      onTap: (!isFuture && count > 0) ? () {
        ref.read(photoProvider.notifier).selectSmartFilter(SmartFilter.monthly, month: month, year: year);
        Navigator.pop(context); 
        Navigator.pop(context); 
      } : null,
      child: Container(
        decoration: BoxDecoration(
          color: isCleaned 
              ? AppTheme.toxicGreen.withOpacity(0.1) 
              : isFuture ? Colors.white.withOpacity(0.02) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCleaned 
                ? AppTheme.toxicGreen.withOpacity(0.4) 
                : isFuture ? Colors.transparent : Colors.white.withOpacity(0.05),
            width: 1,
          ),
          gradient: isCleaned ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.toxicGreen.withOpacity(0.2), 
              AppTheme.electricViolet.withOpacity(0.1)
            ],
          ) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              monthName,
              style: GoogleFonts.plusJakartaSans(
                color: isFuture ? Colors.white10 : Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            if (isCleaned)
              Column(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: AppTheme.toxicGreen, size: 12),
                  const SizedBox(height: 2),
                  Text(
                    'CLEANED',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.toxicGreen,
                      fontWeight: FontWeight.w900,
                      fontSize: 7,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              )
            else if (isFuture)
              const Icon(Icons.lock_outline_rounded, color: Colors.white10, size: 12)
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.electricViolet.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.electricViolet,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
