import 'package:flutter/material.dart';

class VideoRotationControl extends StatelessWidget {
  final Function(int) onRotationChanged;
  final int currentRotation;

  const VideoRotationControl({
    super.key,
    required this.onRotationChanged,
    required this.currentRotation,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.rotate_left, color: Colors.white),
            onPressed: () => onRotationChanged((currentRotation - 90) % 360),
          ),
          SizedBox(
            width: 60,
            child: Text(
              '$currentRotation°',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.rotate_right, color: Colors.white),
            onPressed: () => onRotationChanged((currentRotation + 90) % 360),
          ),
        ],
      ),
    );
  }
}
