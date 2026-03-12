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
  final int _blobCount = 4; // Увеличил до 4, чтобы всегда был свет в разных частях

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
        // Сделал основной фон светлее и равномернее фиолетовым
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1E0B36), // Чуть ярче сверху
                Color(0xFF140726), // Теперь низ НЕ черный, а глубокий фиолетовый
              ],
            ),
          ),
        ),
        
        ...List.generate(_blobCount, (index) {
          return AnimatedBuilder(
            animation: _controllers[index],
            builder: (context, child) {
              final double t = _controllers[index].value * 2 * math.pi;
              
              // Настраиваем траектории так, чтобы они покрывали весь экран
              double x = math.sin(t + index * 1.5) * 0.7; 
              double y = math.cos(t * 0.4 + index * 2.0) * 0.6;

              // Если это 4-й шар (index 3), принудительно тянем его чуть ниже центра
              if (index == 3) {
                y = 0.4 + math.sin(t * 0.5) * 0.3; // Плавает в нижней части экрана
              }
              
              Color blobColor;
              if (index == 0) {
                blobColor = AppTheme.electricViolet;
              } else if (index == 1) {
                blobColor = const Color(0xFFC084FC);
              } else if (index == 2) {
                blobColor = const Color(0xFFE9D5FF);
              } else {
                blobColor = const Color(0xFF9D50BB); // Насыщенный фиолетовый для низа
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
