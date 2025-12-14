import 'package:flutter/material.dart';
import 'orientation_logo.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Stack(
        children: [
          // Background with geometric shapes
          const GeometricBackground(),
          // Logo centered
          const Positioned(
            left: 0,
            right: 0,
            bottom: 30,
            child: Center(
              child: OrientationLogo(),
            ),
          ),
        ],
      ),
    );
  }
}

class GeometricBackground extends StatelessWidget {
  const GeometricBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: CustomPaint(
        painter: _GeometricPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _GeometricPainter extends CustomPainter {
  // Colors from Figma specs
  static const Color rect33Color = Color(0xFF260002); // Main center shape
  static const Color rect34Color = Color(0xFF170001); // Right shape  
  static const Color rect32Color = Color(0xFF170001); // Left shape

  // Rotation angle: -55.7 degrees in radians
  static const double rotationAngle = -55.7 * 3.14159265359 / 180;

  @override
  void paint(Canvas canvas, Size size) {
    // Rectangle 34 (back layer - top right area)
    // Width: 185.1px, Height: 112.17px
    _drawRotatedRect(
      canvas,
      centerX: 153,  // Left (أفقي) - زوّد الرقم = يروح يمين
      centerY: -67.04,  // Top (رأسي) - زوّد الرقم = ينزل تحت
      width: 185.1,
      height: 112.17,
      color: rect34Color,
    );

    // Rectangle 32 (middle layer - left area)
    // Width: 185.1px, Height: 112.17px
    _drawRotatedRect(
      canvas,
      centerX: 71.55,    // Left (أفقي)
      centerY: 95.41,   // Top (رأسي)
      width: 185.1,
      height: 112.17,
      color: rect32Color,
    );

    // Rectangle 33 (front layer - center, main shape)
    // Width: 212.12px, Height: 119.97px
    _drawRotatedRect(
      canvas,
      centerX: 89.8,  // Left (أفقي)
      centerY: 0.48,   // Top (رأسي)
      width: 212.12,
      height: 119.97,
      color: rect33Color,
    );

    // Gradient overlay for smooth transition to black
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(0.3),
          Colors.black.withOpacity(0.8),
          Colors.black,
        ],
        stops: const [0.0, 0.5, 0.8, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), gradientPaint);
  }

  void _drawRotatedRect(
    Canvas canvas, {
    required double centerX,
    required double centerY,
    required double width,
    required double height,
    required Color color,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.save();
    
    // Translate to the center of the rectangle
    canvas.translate(centerX, centerY);
    
    // Rotate around the center (like Figma does)
    canvas.rotate(rotationAngle);
    
    // Draw the rectangle centered at origin
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: width, height: height),
      paint,
    );
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

