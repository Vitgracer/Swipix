import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme.dart';

class AnimatedAurora extends StatefulWidget {
  const AnimatedAurora({super.key});

  @override
  State<AnimatedAurora> createState() => _AnimatedAuroraState();
}

class _AnimatedAuroraState extends State<AnimatedAurora> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(
                math.sin(_controller.value * 2 * math.pi) * 0.3,
                math.cos(_controller.value * 2 * math.pi) * 0.3,
              ),
              radius: 1.8,
              colors: [
                AppTheme.electricViolet.withOpacity(0.12),
                AppTheme.black,
              ],
            ),
          ),
        );
      },
    );
  }
}
