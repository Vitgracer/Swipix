import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/photo_provider.dart';
import '../core/theme.dart';
import '../widgets/animated_aurora.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(photoProvider);

    return Scaffold(
      backgroundColor: AppTheme.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('ANALYTICS', style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const AnimatedAurora(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('LIFETIME IMPACT'),
                const SizedBox(height: 16),
                _buildLifetimeCards(state),
                const SizedBox(height: 40),
                _buildSectionTitle('WEEKLY ACTIVITY (MON - SUN)'),
                const SizedBox(height: 16),
                _buildWeeklyChart(state.weeklyActivity),
                const SizedBox(height: 40),
                _buildLuxuryTip(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildLifetimeCards(PhotoState state) {
    return Column(
      children: [
        _buildGlassStatCard(
          'SPACE RELEASED',
          '${state.lifetimeSpaceReleased.toStringAsFixed(1)} MB',
          Icons.auto_delete_rounded,
          AppTheme.electricViolet,
          subtitle: 'Actual storage reclaimed',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSmallGlassCard(
                'APPROVED',
                '${state.lifetimeKept}',
                AppTheme.toxicGreen,
                Icons.check_circle_outline_rounded,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSmallGlassCard(
                'TRASHED',
                '${state.lifetimeTrashed}',
                AppTheme.bloodRed,
                Icons.delete_outline_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeeklyChart(Map<String, int> weeklyActivity) {
    // Logic for Mon - Sun week
    final now = DateTime.now();
    // Monday is 1, Sunday is 7. We want to find the most recent Monday.
    final monday = now.subtract(Duration(days: now.weekday - 1));
    
    final List<String> weekDays = List.generate(7, (index) {
      final date = monday.add(Duration(days: index));
      return DateFormat('yyyy-MM-dd').format(date);
    });

    final List<BarChartGroupData> barGroups = [];
    int maxVal = 10; // Default min height for visual consistency

    for (int i = 0; i < weekDays.length; i++) {
      final count = weeklyActivity[weekDays[i]] ?? 0;
      if (count > maxVal) maxVal = count;
    }

    for (int i = 0; i < weekDays.length; i++) {
      final count = weeklyActivity[weekDays[i]] ?? 0;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              gradient: LinearGradient(
                colors: [AppTheme.electricViolet, AppTheme.electricViolet.withOpacity(0.4)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              width: 14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxVal.toDouble(),
                color: Colors.white.withOpacity(0.03),
              ),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 220,
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: BarChart(
            BarChartData(
              maxY: maxVal.toDouble(),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  tooltipBgColor: AppTheme.cardBg,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${rod.toY.toInt()}',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                      return Padding(
                        padding: const EdgeInsets.only(top: 10.0),
                        child: Text(
                          days[value.toInt()],
                          style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: barGroups,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassStatCard(String title, String value, IconData icon, Color color, {required String subtitle}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      value,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white24, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallGlassCard(String title, String value, Color color, IconData icon) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color.withOpacity(0.5), size: 20),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLuxuryTip() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.electricViolet.withOpacity(0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.electricViolet.withOpacity(0.1)),
      ),
      child: const Row(
        children: [
          Icon(Icons.insights_rounded, color: AppTheme.electricViolet, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Consistency is the key to a clutter-free digital life.',
              style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
