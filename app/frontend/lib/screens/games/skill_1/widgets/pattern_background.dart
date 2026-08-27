import 'dart:ui';
import 'package:flutter/material.dart';

class PatternBackground extends StatelessWidget {
  final String imagePath;
  
  const PatternBackground({
    Key? key, 
    required this.imagePath,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            imagePath,
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              color: Colors.white.withValues(alpha: 0.75), // Semi-transparent white to ensure UI legibility
            ),
          ),
        ),
      ],
    );
  }
}
