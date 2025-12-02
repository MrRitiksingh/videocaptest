import 'package:flutter/material.dart';

class ConcaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path();
    const double curveHeight = 20.0; // Adjust this value for the concave depth

    // Start from the top left
    path.lineTo(0, 0);
    // Draw line to top right
    path.lineTo(size.width, 0);
    // Draw a curve to the bottom right
    path.lineTo(size.width, size.height - curveHeight);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      0,
      size.height - curveHeight,
    );
    // Close the path
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class DeepConcaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path();
    const double curveHeight = 40.0;
    path.lineTo(0, 0);
    path.quadraticBezierTo(
      size.height,
      size.height,
      size.width,
      0,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, size.height - curveHeight);
    path.lineTo(size.width, size.height - curveHeight);
    // path.quadraticBezierTo(
    //   size.width / 2,
    //   size.height + curveHeight,
    //   0,
    //   size.height - curveHeight,
    // );
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class MyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint();
    Path path = Path();
    paint.color = const Color.fromRGBO(40, 39, 80, 1);
    path = Path();
    path.lineTo(size.width * 0.42, 0);
    path.cubicTo(
        size.width * 0.42, 0, size.width * 0.58, 0, size.width * 0.58, 0);
    path.cubicTo(size.width * 0.71, 0, size.width * 0.74, size.height * 0.24,
        size.width * 0.78, size.height * 0.49);
    path.cubicTo(size.width * 0.82, size.height * 0.74, size.width * 0.86,
        size.height, size.width, size.height);
    path.cubicTo(size.width, size.height, 0, size.height, 0, size.height);
    path.cubicTo(size.width * 0.14, size.height, size.width * 0.18,
        size.height * 0.74, size.width * 0.22, size.height * 0.49);
    path.cubicTo(size.width * 0.26, size.height * 0.24, size.width * 0.29, 0,
        size.width * 0.42, 0);
    path.cubicTo(
        size.width * 0.42, 0, size.width * 0.42, 0, size.width * 0.42, 0);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

class InwardCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path();
    const double curveDepth =
        50.0; // Adjust this value for the depth of the inward curve

    // Start from the top left
    path.lineTo(0, 0);
    // Create an inward curve towards the top right
    path.quadraticBezierTo(
      size.width / 2, // Control point x (middle of the width)
      curveDepth, // Control point y (depth of the inward curve)
      size.width, // End point x (top right corner)
      0, // End point y (top right corner)
    );
    // Draw a line to the bottom right
    path.lineTo(size.width, size.height);
    // Draw a line to the bottom left
    path.lineTo(0, size.height);
    // Close the path back to the starting point (top left)
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class CurvedEdgeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path();

    // Top curve (less pronounced)
    path.moveTo(0, 10);
    path.quadraticBezierTo(size.width / 2, -10, size.width, 10);

    // Right side
    path.lineTo(size.width, size.height - 20);

    // Bottom curve (more pronounced)
    path.quadraticBezierTo(
        size.width / 2, size.height + 20, 0, size.height - 20);

    // Close the path
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class ConvexClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path();
    const double curveHeight = 40.0; // Height of the convex curve

    // Start from the top left
    path.lineTo(0, 0);
    // Draw line to the top right
    path.lineTo(size.width, 0);
    // Draw a line down to where the convex curve will start
    path.lineTo(size.width, curveHeight);
    // Create the convex curve at the top
    path.quadraticBezierTo(
      size.width / 2, // Control point x (middle of the width)
      -curveHeight,
      // Control point y (above the top edge to create outward bulge)
      0, // End point x (top left)
      curveHeight, // End point y (just below the curve start)
    );
    // Close the path by drawing a line to the starting point
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class TopConcaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path();
    final double curveHeight = 40.0; // Adjust this value for the concave depth

    // Move to the top left corner
    path.lineTo(0, 0);
    // Draw line to the top right corner
    path.lineTo(size.width, 0);
    // Create the concave curve
    path.lineTo(
        size.width, curveHeight); // Go down by curveHeight to start the curve
    path.quadraticBezierTo(
      size.width / 2,
      -curveHeight,
      // Move the control point up by curveHeight to create the concave effect
      0,
      curveHeight, // End the curve at the left side
    );
    // Close the path
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
