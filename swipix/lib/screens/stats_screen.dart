import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      ),
      body: Stack(
        children: [
          const AnimatedAurora(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
            child: Column(
              children: [
                _buildGlassStatCard(
                  'SPACE RELEASED',
                  '${state.storageSaved.toStringAsFixed(1)} MB',
                  Icons.bolt_rounded,
                  AppTheme.electricViolet,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _buildSmallGlassCard('SAVED', '${state.keptCount}', AppTheme.toxicGreen)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildSmallGlassCard('TRASHED', '${state.trashCount}', AppTheme.bloodRed)),
                  ],
                ),
                const SizedBox(height: 40),
                _buildLuxuryTip(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassStatCard(String title, String value, IconData icon, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 20)],
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallGlassCard(String title, String value, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLuxuryTip() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.electricViolet.withOpacity(0.1),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppTheme.electricViolet.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppTheme.electricViolet, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Your digital space is becoming a curated gallery of excellence.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
