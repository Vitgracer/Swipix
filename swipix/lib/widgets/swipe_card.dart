import 'dart:math';
import 'package:flutter/material.dart';
import '../models/photo_item.dart';
import 'photo_card.dart';

class SwipeCard extends StatefulWidget {
  final PhotoItem photo;
  final Function(bool isKeep) onSwipe;

  const SwipeCard({
    super.key,
    required this.photo,
    required this.onSwipe,
  });

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Offset _offset = Offset.zero;
  double _angle = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _offset += details.delta;
      _angle = 0.1 * (_offset.dx / 100);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_offset.dx > 100) {
      _swipe(true);
    } else if (_offset.dx < -100) {
      _swipe(false);
    } else {
      _resetPosition();
    }
  }

  void _swipe(bool isKeep) {
    final finalOffset = isKeep ? const Offset(500, 0) : const Offset(-500, 0);
    _controller.forward(); // Optional animation trigger
    widget.onSwipe(isKeep);
  }

  void _resetPosition() {
    setState(() {
      _offset = Offset.zero;
      _angle = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Transform.translate(
        offset: _offset,
        child: Transform.rotate(
          angle: _angle,
          child: Stack(
            children: [
              PhotoCard(photo: widget.photo),
              if (_offset.dx > 20)
                Positioned(
                  top: 40,
                  left: 20,
                  child: _buildOverlay('KEEP', Colors.green, max(0, min(1, _offset.dx / 100))),
                ),
              if (_offset.dx < -20)
                Positioned(
                  top: 40,
                  right: 20,
                  child: _buildOverlay('TRASH', Colors.red, max(0, min(1, -_offset.dx / 100))),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(String text, Color color, double opacity) {
    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
