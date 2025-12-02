import 'package:flutter/material.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/transition_picker.dart';

/// Floating transition button that appears between video tracks
/// Similar to VN Video Editor's UI
class TransitionButton extends StatelessWidget {
  final int trackIndex; // Index of track BEFORE the transition
  final TransitionType? currentTransition;
  final VoidCallback onTap;

  const TransitionButton({
    required this.trackIndex,
    required this.currentTransition,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: currentTransition == null ||
                  currentTransition == TransitionType.none
              ? Icon(Icons.add, color: Colors.black, size: 22)
              : Icon(Icons.animation, color: Colors.blue, size: 20),
        ),
      ),
    );
  }
}
