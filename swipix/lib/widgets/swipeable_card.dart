import 'dart:math';
import 'package:flutter/material.dart';
import '../models/photo_item.dart';
import 'photo_card.dart';

class SwipeableCard extends StatefulWidget {
  final PhotoItem photo;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  final int index;

  const SwipeableCard({
    super.key,
    required this.photo,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    required this.index,
  });

  @override
  State<SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<SwipeableCard> with SingleTickerProviderStateMixin {
  Offset _dragOffset = Offset.zero;
  double _angle = 0;
  bool _isDragging = false;
  
  late AnimationController _animController;
  late Animation<Offset> _positionAnimation;
  late Animation<double> _angleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _animController.addListener(() {
      if (_animController.isAnimating) {
        setState(() {
          _dragOffset = _positionAnimation.value;
          _angle = _angleAnimation.value;
        });
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_animController.isAnimating) return;
    setState(() {
      _dragOffset += details.delta;
      _angle = 0.12 * (_dragOffset.dx / 200);
      _isDragging = true;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_animController.isAnimating) return;
    
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (_dragOffset.dx > 140 || velocity > 800) {
      _swipe(true);
    } else if (_dragOffset.dx < -140 || velocity < -800) {
      _swipe(false);
    } else {
      _reset();
    }
  }

  void _swipe(bool isRight) {
    _isDragging = false;
    _positionAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset(isRight ? 1500 : -1500, _dragOffset.dy),
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeInCubic));
    
    _angleAnimation = Tween<double>(begin: _angle, end: _angle * 2)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeInCubic));

    _animController.duration = const Duration(milliseconds: 300);
    _animController.forward(from: 0).then((_) {
      if (isRight) widget.onSwipeRight(); else widget.onSwipeLeft();
    });
  }

  void _reset() {
    _isDragging = false;
    _positionAnimation = Tween<Offset>(begin: _dragOffset, end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.elasticOut));
    
    _angleAnimation = Tween<double>(begin: _angle, end: 0)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.elasticOut));
    
    _animController.duration = const Duration(milliseconds: 600);
    _animController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final stackScale = (1.0 - (widget.index * 0.03)).clamp(0.9, 1.0);
    final stackOffset = widget.index * 12.0;

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutBack,
        transform: Matrix4.identity()
          ..translate(_dragOffset.dx, _dragOffset.dy + stackOffset)
          ..rotateZ(_angle)
          ..scale(_isDragging ? 1.03 : stackScale),
        child: GestureDetector(
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: SizedBox(
            width: size.width * 0.95,
            height: size.height * 0.78,
            child: Stack(
              children: [
                PhotoCard(photo: widget.photo),
                if (_dragOffset.dx.abs() > 20) _buildLuxuryGlowOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLuxuryGlowOverlay() {
    final isRight = _dragOffset.dx > 0;
    final opacity = (_dragOffset.dx.abs() / 150).clamp(0.0, 1.0);
    final color = isRight ? Colors.greenAccent[400]! : Colors.redAccent[400]!;
    
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: RadialGradient(
            center: Alignment(isRight ? -0.6 : 0.6, -0.2),
            radius: 1.4,
            colors: [
              color.withOpacity(opacity * 0.5),
              Colors.transparent,
            ],
          ),
        ),
        child: Center(
          child: Opacity(
            opacity: opacity,
            child: Text(
              isRight ? 'KEEP' : 'TRASH',
              style: TextStyle(
                color: Colors.white,
                fontSize: 72,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
                shadows: [
                  Shadow(color: color.withOpacity(0.8), blurRadius: 30),
                  Shadow(color: color.withOpacity(0.5), blurRadius: 60),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
