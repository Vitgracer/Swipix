import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme.dart';

class AnimatedAurora extends StatefulWidget {
  const AnimatedAurora({super.key});

  @override
  State<AnimatedAurora> createState() => _AnimatedAuroraState();
}

class _AnimatedAuroraState extends State<AnimatedAurora> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  final int _blobCount = 4; // Increased to 4 to ensure light in all parts of the screen

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_blobCount, (index) {
      return AnimationController(
        vsync: this,
        duration: Duration(seconds: 12 + index * 4),
      )..repeat();
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main background: Deep violet gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1E0B36), // Slightly brighter top
                Color(0xFF140726), // Deep violet bottom (not pure black)
              ],
            ),
          ),
        ),
        
        ...List.generate(_blobCount, (index) {
          return AnimatedBuilder(
            animation: _controllers[index],
            builder: (context, child) {
              final double t = _controllers[index].value * 2 * math.pi;
              
              // Set trajectories to cover the whole screen
              double x = math.sin(t + index * 1.5) * 0.7; 
              double y = math.cos(t * 0.4 + index * 2.0) * 0.6;

              // Force the 4th blob to stay in the lower part of the screen
              if (index == 3) {
                y = 0.4 + math.sin(t * 0.5) * 0.3; 
              }
              
              Color blobColor;
              if (index == 0) {
                blobColor = AppTheme.electricViolet;
              } else if (index == 1) {
                blobColor = const Color(0xFFC084FC);
              } else if (index == 2) {
                blobColor = const Color(0xFFE9D5FF);
              } else {
                blobColor = const Color(0xFF9D50BB);
              }

              return Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(x, y),
                      radius: 1.5,
                      colors: [
                        blobColor.withOpacity(0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }
}
