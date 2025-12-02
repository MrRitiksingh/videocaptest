import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/transition_picker.dart';

/// Engine for rendering transition effects between two video frames
/// Uses Flutter's built-in animation capabilities for smooth transitions
class TransitionPreviewEngine {
  /// Apply transition effect to blend two widgets (video frames)
  ///
  /// [fromWidget] - The outgoing video frame (current track)
  /// [toWidget] - The incoming video frame (next track)
  /// [transitionType] - The type of transition effect to apply
  /// [progress] - Animation progress from 0.0 (start) to 1.0 (end)
  ///
  /// Returns a widget that renders the transition effect at the given progress
  static Widget applyTransition({
    required Widget fromWidget,
    required Widget toWidget,
    required TransitionType transitionType,
    required double progress,
  }) {
    // Clamp progress to valid range
    final clampedProgress = progress.clamp(0.0, 1.0);

    switch (transitionType) {
      case TransitionType.none:
        // No transition - just show outgoing video until very end
        return clampedProgress < 0.99 ? fromWidget : toWidget;

      case TransitionType.fade:
        return _applyFade(fromWidget, toWidget, clampedProgress);

      case TransitionType.fadeblack:
        return _applyFadeBlack(fromWidget, toWidget, clampedProgress);

      case TransitionType.fadewhite:
        return _applyFadeWhite(fromWidget, toWidget, clampedProgress);

      case TransitionType.wipeleft:
        return _applyWipe(
            fromWidget, toWidget, clampedProgress, Alignment.centerRight);

      case TransitionType.wiperight:
        return _applyWipe(
            fromWidget, toWidget, clampedProgress, Alignment.centerLeft);

      case TransitionType.wipeup:
        return _applyWipe(
            fromWidget, toWidget, clampedProgress, Alignment.bottomCenter);

      case TransitionType.wipedown:
        return _applyWipe(
            fromWidget, toWidget, clampedProgress, Alignment.topCenter);

      case TransitionType.slideleft:
        return _applySlide(
            fromWidget, toWidget, clampedProgress, const Offset(-1, 0));

      case TransitionType.slideright:
        return _applySlide(
            fromWidget, toWidget, clampedProgress, const Offset(1, 0));

      case TransitionType.slideup:
        return _applySlide(
            fromWidget, toWidget, clampedProgress, const Offset(0, -1));

      case TransitionType.slidedown:
        return _applySlide(
            fromWidget, toWidget, clampedProgress, const Offset(0, 1));

      case TransitionType.smoothleft:
        return _applySmoothSlide(
            fromWidget, toWidget, clampedProgress, const Offset(-1, 0));

      case TransitionType.smoothright:
        return _applySmoothSlide(
            fromWidget, toWidget, clampedProgress, const Offset(1, 0));

      case TransitionType.smoothup:
        return _applySmoothSlide(
            fromWidget, toWidget, clampedProgress, const Offset(0, -1));

      case TransitionType.smoothdown:
        return _applySmoothSlide(
            fromWidget, toWidget, clampedProgress, const Offset(0, 1));

      case TransitionType.zoomin:
        return _applyZoomIn(fromWidget, toWidget, clampedProgress);

      case TransitionType.circleclose:
        return _applyCircleClose(fromWidget, toWidget, clampedProgress);

      case TransitionType.circleopen:
        return _applyCircleOpen(fromWidget, toWidget, clampedProgress);

      // Barn door transitions (horizontal = left-right motion uses vertical clipper, vertical = top-bottom motion uses horizontal clipper)
      case TransitionType.horzclose:
        return _applyBarnDoorVertClose(fromWidget, toWidget, clampedProgress);

      case TransitionType.horzopen:
        return _applyBarnDoorVertOpen(fromWidget, toWidget, clampedProgress);

      case TransitionType.vertclose:
        return _applyBarnDoorHorzClose(fromWidget, toWidget, clampedProgress);

      case TransitionType.vertopen:
        return _applyBarnDoorHorzOpen(fromWidget, toWidget, clampedProgress);

      // Squeeze transitions (squeezeh = vertical squeeze, squeezev = horizontal squeeze)
      case TransitionType.squeezeh:
        return _applySqueezeVertical(fromWidget, toWidget, clampedProgress);

      case TransitionType.squeezev:
        return _applySqueezeHorizontal(fromWidget, toWidget, clampedProgress);

      // Crop transitions
      case TransitionType.circlecrop:
        return _applyCircleCrop(fromWidget, toWidget, clampedProgress);

      case TransitionType.rectcrop:
        return _applyRectCrop(fromWidget, toWidget, clampedProgress);

      // Diagonal wipe transitions
      // Note: Mappings are swapped to match FFmpeg xfade behavior
      case TransitionType.diagbl:
        return _applyDiagonalWipe(
            fromWidget, toWidget, clampedProgress, DiagonalDirection.topRight);

      case TransitionType.diagbr:
        return _applyDiagonalWipe(
            fromWidget, toWidget, clampedProgress, DiagonalDirection.topLeft);

      case TransitionType.diagtl:
        return _applyDiagonalWipe(fromWidget, toWidget, clampedProgress,
            DiagonalDirection.bottomRight);

      case TransitionType.diagtr:
        return _applyDiagonalWipe(fromWidget, toWidget, clampedProgress,
            DiagonalDirection.bottomLeft);

      case TransitionType.distance:
        return _applyDistance(fromWidget, toWidget, clampedProgress);

      case TransitionType.fadegrays:
        return _applyFadeGrays(fromWidget, toWidget, clampedProgress);
    }
  }

  /// Simple crossfade transition
  static Widget _applyFade(Widget from, Widget to, double progress) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Outgoing video fades out
        Opacity(
          opacity: 1.0 - progress,
          child: from,
        ),
        // Incoming video fades in
        Opacity(
          opacity: progress,
          child: to,
        ),
      ],
    );
  }

  /// Fade through black (fade out to black, then fade in from black)
  static Widget _applyFadeBlack(Widget from, Widget to, double progress) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Black background
        Container(color: Colors.black),
        // First half: fade out to black
        if (progress < 0.5)
          Opacity(
            opacity: 1.0 - (progress * 2),
            child: from,
          ),
        // Second half: fade in from black
        if (progress >= 0.5)
          Opacity(
            opacity: (progress - 0.5) * 2,
            child: to,
          ),
      ],
    );
  }

  /// Fade through white (fade out to white, then fade in from white)
  static Widget _applyFadeWhite(Widget from, Widget to, double progress) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // White background
        Container(color: Colors.white),
        // First half: fade out to white
        if (progress < 0.5)
          Opacity(
            opacity: 1.0 - (progress * 2),
            child: from,
          ),
        // Second half: fade in from white
        if (progress >= 0.5)
          Opacity(
            opacity: (progress - 0.5) * 2,
            child: to,
          ),
      ],
    );
  }

  /// Wipe transition (incoming video wipes across from a direction)
  /// Uses custom clipper for proper directional reveal
  static Widget _applyWipe(
      Widget from, Widget to, double progress, Alignment alignment) {
    print(
        '🎬 Wipe transition called: progress=${(progress * 100).toStringAsFixed(1)}%, alignment=$alignment');

    return Stack(
      fit: StackFit.expand,
      children: [
        // Outgoing video (stays full screen)
        from,
        // Incoming video (progressively revealed from direction)
        ClipRect(
          clipper: _WipeClipper(
            progress: progress,
            alignment: alignment,
          ),
          child: to,
        ),
      ],
    );
  }

  /// Slide transition (both videos slide, old slides out, new slides in)
  static Widget _applySlide(
      Widget from, Widget to, double progress, Offset direction) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Outgoing video slides out in the direction
        ClipRect(
          child: Transform.translate(
            offset: Offset(
              direction.dx *
                  progress *
                  1000, // Multiply by large value to slide off screen
              direction.dy * progress * 1000,
            ),
            child: from,
          ),
        ),
        // Incoming video slides in from opposite direction
        ClipRect(
          child: Transform.translate(
            offset: Offset(
              -direction.dx * (1 - progress) * 1000,
              -direction.dy * (1 - progress) * 1000,
            ),
            child: to,
          ),
        ),
      ],
    );
  }

  /// Smooth slide transition (professional multi-effect approach)
  /// Combines easing curve + scale animation + opacity crossfade for visible distinction
  /// Similar to professional video editors (After Effects, Premiere Pro, CapCut)
  static Widget _applySmoothSlide(
      Widget from, Widget to, double progress, Offset direction) {
    // 1. Apply ease-in-out quintic curve for pronounced smooth motion
    final easedProgress = Curves.easeInOutQuint.transform(progress);

    // 2. Subtle scale animation: 1.0 → 1.025 → 1.0 (peaks at 50% progress)
    // Creates a "breathing" effect during motion - common in pro editors
    final scaleProgress = 1.0 + (0.025 * (1 - (2 * progress - 1).abs()));

    // 3. Opacity crossfade: Creates softer visual blending vs hard slide
    // Outgoing: 100% → 70%, Incoming: 70% → 100%
    final fromOpacity = (1.0 - progress * 0.3).clamp(0.7, 1.0);
    final toOpacity = (0.7 + progress * 0.3).clamp(0.7, 1.0);

    print('🎬 Smooth slide: progress=${(progress * 100).toStringAsFixed(1)}%, '
        'eased=${(easedProgress * 100).toStringAsFixed(1)}%, '
        'scale=${scaleProgress.toStringAsFixed(3)}, '
        'opacity from/to: ${fromOpacity.toStringAsFixed(2)}/${toOpacity.toStringAsFixed(2)}');

    return Stack(
      fit: StackFit.expand,
      children: [
        // Outgoing video: eased slide + fade out + subtle scale
        ClipRect(
          child: Opacity(
            opacity: fromOpacity,
            child: Transform.scale(
              scale: scaleProgress,
              child: Transform.translate(
                offset: Offset(
                  direction.dx * easedProgress * 1000,
                  direction.dy * easedProgress * 1000,
                ),
                child: from,
              ),
            ),
          ),
        ),
        // Incoming video: eased slide + fade in + subtle scale
        ClipRect(
          child: Opacity(
            opacity: toOpacity,
            child: Transform.scale(
              scale: scaleProgress,
              child: Transform.translate(
                offset: Offset(
                  -direction.dx * (1 - easedProgress) * 1000,
                  -direction.dy * (1 - easedProgress) * 1000,
                ),
                child: to,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Zoom in transition (new video zooms in from center)
  static Widget _applyZoomIn(Widget from, Widget to, double progress) {
    final scale = 0.5 + (progress * 0.5); // Scale from 50% to 100%

    return Stack(
      fit: StackFit.expand,
      children: [
        from,
        Opacity(
          opacity: progress,
          child: Transform.scale(
            scale: scale,
            child: to,
          ),
        ),
      ],
    );
  }

  /// Circle close transition (circular reveal shrinks from edge to center)
  static Widget _applyCircleClose(Widget from, Widget to, double progress) {
    return Stack(
      fit: StackFit.expand,
      children: [
        to, // Show new video as background
        ClipOval(
          clipper:
              _CircleRevealClipper(progress: 1.0 - progress, reverse: true),
          child: from,
        ),
      ],
    );
  }

  /// Circle open transition (circular reveal expands from center to edge)
  static Widget _applyCircleOpen(Widget from, Widget to, double progress) {
    return Stack(
      fit: StackFit.expand,
      children: [
        from, // Show old video as background
        ClipOval(
          clipper: _CircleRevealClipper(progress: progress, reverse: false),
          child: to,
        ),
      ],
    );
  }

  /// Barn door horizontal close (doors closing from sides to center)
  static Widget _applyBarnDoorHorzClose(
      Widget from, Widget to, double progress) {
    return Stack(
      fit: StackFit.expand,
      children: [
        from,
        ClipRect(
          clipper:
              _BarnDoorHorizontalClipper(progress: progress, opening: false),
          child: to,
        ),
      ],
    );
  }

  /// Barn door horizontal open (doors opening from center to sides)
  static Widget _applyBarnDoorHorzOpen(
      Widget from, Widget to, double progress) {
    return Stack(
      fit: StackFit.expand,
      children: [
        from,
        ClipRect(
          clipper:
              _BarnDoorHorizontalClipper(progress: progress, opening: true),
          child: to,
        ),
      ],
    );
  }

  /// Barn door vertical close (doors closing from top/bottom to center)
  static Widget _applyBarnDoorVertClose(
      Widget from, Widget to, double progress) {
    return Stack(
      fit: StackFit.expand,
      children: [
        from,
        ClipRect(
          clipper: _BarnDoorVerticalClipper(progress: progress, opening: false),
          child: to,
        ),
      ],
    );
  }

  /// Barn door vertical open (doors opening from center to top/bottom)
  static Widget _applyBarnDoorVertOpen(
      Widget from, Widget to, double progress) {
    return Stack(
      fit: StackFit.expand,
      children: [
        from,
        ClipRect(
          clipper: _BarnDoorVerticalClipper(progress: progress, opening: true),
          child: to,
        ),
      ],
    );
  }

  /// Horizontal squeeze transition (videos squeeze horizontally)
  static Widget _applySqueezeHorizontal(
      Widget from, Widget to, double progress) {
    // Outgoing video scale: 1.0 → 0.0 (squeeze to nothing)
    final fromScaleX = 1.0 - progress;
    // Incoming video scale: 0.0 → 1.0 (expand from nothing)
    final toScaleX = progress;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Outgoing video: squeezes horizontally (full width → 0)
        if (fromScaleX > 0.01) // Only show if still visible
          ClipRect(
            child: Center(
              child: Transform.scale(
                scaleX: fromScaleX,
                scaleY: 1.0, // Keep vertical scale normal
                child: from,
              ),
            ),
          ),
        // Incoming video: expands horizontally (0 → full width)
        if (toScaleX > 0.01) // Only show if visible enough
          ClipRect(
            child: Center(
              child: Transform.scale(
                scaleX: toScaleX,
                scaleY: 1.0, // Keep vertical scale normal
                child: to,
              ),
            ),
          ),
      ],
    );
  }

  /// Vertical squeeze transition (videos squeeze vertically)
  static Widget _applySqueezeVertical(Widget from, Widget to, double progress) {
    // Outgoing video scale: 1.0 → 0.0 (squeeze to nothing)
    final fromScaleY = 1.0 - progress;
    // Incoming video scale: 0.0 → 1.0 (expand from nothing)
    final toScaleY = progress;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Outgoing video: squeezes vertically (full height → 0)
        if (fromScaleY > 0.01) // Only show if still visible
          ClipRect(
            child: Center(
              child: Transform.scale(
                scaleX: 1.0, // Keep horizontal scale normal
                scaleY: fromScaleY,
                child: from,
              ),
            ),
          ),
        // Incoming video: expands vertically (0 → full height)
        if (toScaleY > 0.01) // Only show if visible enough
          ClipRect(
            child: Center(
              child: Transform.scale(
                scaleX: 1.0, // Keep horizontal scale normal
                scaleY: toScaleY,
                child: to,
              ),
            ),
          ),
      ],
    );
  }

  /// Circle crop transition (iris wipe: close old video, then open new video)
  static Widget _applyCircleCrop(Widget from, Widget to, double progress) {
    if (progress < 0.5) {
      // Phase 1 (0% → 50%): Circle closes on old video (iris close)
      // Map progress 0.0→0.5 to clipper 1.0→0.0 (full circle shrinks to center point)
      final closeProgress = 1.0 - (progress * 2);
      return Stack(
        fit: StackFit.expand,
        children: [
          to, // Show new video as background (will be revealed when circle closes completely)
          ClipOval(
            clipper:
                _CircleRevealClipper(progress: closeProgress, reverse: false),
            child: from,
          ),
        ],
      );
    } else {
      // Phase 2 (50% → 100%): Circle opens on new video (iris open)
      // Map progress 0.5→1.0 to clipper 0.0→1.0 (center point expands to full circle)
      final openProgress = (progress - 0.5) * 2;
      return Stack(
        fit: StackFit.expand,
        children: [
          from, // Old video as background (not visible anymore after phase 1)
          ClipOval(
            clipper:
                _CircleRevealClipper(progress: openProgress, reverse: false),
            child: to,
          ),
        ],
      );
    }
  }

  /// Rectangle crop transition (box iris wipe: close old video, then open new video)
  static Widget _applyRectCrop(Widget from, Widget to, double progress) {
    if (progress < 0.5) {
      // Phase 1 (0% → 50%): Rectangle closes on old video (box iris close)
      // Map progress 0.0→0.5 to clipper 1.0→0.0 (full rectangle shrinks to center point)
      final closeProgress = 1.0 - (progress * 2);
      return Stack(
        fit: StackFit.expand,
        children: [
          to, // Show new video as background (will be revealed when rectangle closes completely)
          ClipRect(
            clipper: _RectCropClipper(progress: closeProgress),
            child: from,
          ),
        ],
      );
    } else {
      // Phase 2 (50% → 100%): Rectangle opens on new video (box iris open)
      // Map progress 0.5→1.0 to clipper 0.0→1.0 (center point expands to full rectangle)
      final openProgress = (progress - 0.5) * 2;
      return Stack(
        fit: StackFit.expand,
        children: [
          from, // Old video as background (not visible anymore after phase 1)
          ClipRect(
            clipper: _RectCropClipper(progress: openProgress),
            child: to,
          ),
        ],
      );
    }
  }

  /// Diagonal wipe transition (wipe from corner at 45-degree angle)
  static Widget _applyDiagonalWipe(
      Widget from, Widget to, double progress, DiagonalDirection direction) {
    return Stack(
      fit: StackFit.expand,
      children: [
        from,
        ClipPath(
          clipper:
              _DiagonalWipeClipper(progress: progress, direction: direction),
          child: to,
        ),
      ],
    );
  }

  /// Distance transition (blends based on pixel difference between frames)
  /// Simulates FFmpeg's distance effect using blur and opacity
  static Widget _applyDistance(Widget from, Widget to, double progress) {
    // Distance effect: progressively reveals new video with a blur effect
    // simulating the "distance" calculation between pixel values

    // Calculate opacity for crossfade
    final fromOpacity = 1.0 - progress;
    final toOpacity = progress;

    // Blur intensity decreases as transition progresses
    // Start with high blur, end with no blur for sharp transition
    final blurSigma = (1.0 - progress) * 5.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Outgoing video: fade out with increasing blur
        if (fromOpacity > 0.01)
          Opacity(
            opacity: fromOpacity,
            child: blurSigma > 0.5
                ? ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: blurSigma,
                      sigmaY: blurSigma,
                      tileMode: TileMode.decal,
                    ),
                    child: from,
                  )
                : from,
          ),
        // Incoming video: fade in with decreasing blur
        if (toOpacity > 0.01)
          Opacity(
            opacity: toOpacity,
            child: blurSigma > 0.5
                ? ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: blurSigma,
                      sigmaY: blurSigma,
                      tileMode: TileMode.decal,
                    ),
                    child: to,
                  )
                : to,
          ),
      ],
    );
  }

  /// Fade through gray (fade out to gray, then fade in from gray)
  static Widget _applyFadeGrays(Widget from, Widget to, double progress) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Gray background
        Container(color: Color(0xFF808080)), // Medium gray
        // First half: fade out to gray
        if (progress < 0.5)
          Opacity(
            opacity: 1.0 - (progress * 2),
            child: from,
          ),
        // Second half: fade in from gray
        if (progress >= 0.5)
          Opacity(
            opacity: (progress - 0.5) * 2,
            child: to,
          ),
      ],
    );
  }
}

/// Enum for diagonal wipe directions
enum DiagonalDirection {
  topLeft, // Wipe from top-left corner
  topRight, // Wipe from top-right corner
  bottomLeft, // Wipe from bottom-left corner
  bottomRight // Wipe from bottom-right corner
}

/// Custom clipper for horizontal barn door transitions
/// Doors close/open from sides to center or center to sides
class _BarnDoorHorizontalClipper extends CustomClipper<Rect> {
  final double progress;
  final bool opening;

  _BarnDoorHorizontalClipper({required this.progress, required this.opening});

  @override
  Rect getClip(Size size) {
    if (opening) {
      // Opening: Doors start closed at center, open to reveal full width (center → edges)
      // At 0%: center slit (width = 0), At 100%: full reveal (width = full)
      final revealWidth = size.width * progress;
      final left = (size.width - revealWidth) / 2;
      return Rect.fromLTWH(left, 0, revealWidth, size.height);
    } else {
      // Closing: Doors start open at edges, close to center (edges → center)
      // At 0%: full reveal (show old video), At 100%: center slit only (show new video)
      // Invert progress: show old video shrinking, new video revealed at edges
      final revealWidth = size.width * (1.0 - progress);
      final left = (size.width - revealWidth) / 2;
      return Rect.fromLTWH(left, 0, revealWidth, size.height);
    }
  }

  @override
  bool shouldReclip(_BarnDoorHorizontalClipper oldClipper) {
    return oldClipper.progress != progress || oldClipper.opening != opening;
  }
}

/// Custom clipper for vertical barn door transitions
/// Doors close/open from top/bottom to center or center to top/bottom
class _BarnDoorVerticalClipper extends CustomClipper<Rect> {
  final double progress;
  final bool opening;

  _BarnDoorVerticalClipper({required this.progress, required this.opening});

  @override
  Rect getClip(Size size) {
    if (opening) {
      // Opening: Doors start closed at center, open to reveal full height (center → edges)
      // At 0%: center slit (height = 0), At 100%: full reveal (height = full)
      final revealHeight = size.height * progress;
      final top = (size.height - revealHeight) / 2;
      return Rect.fromLTWH(0, top, size.width, revealHeight);
    } else {
      // Closing: Doors start open at edges, close to center (edges → center)
      // At 0%: full reveal (show old video), At 100%: center slit only (show new video)
      // Invert progress: show old video shrinking, new video revealed at edges
      final revealHeight = size.height * (1.0 - progress);
      final top = (size.height - revealHeight) / 2;
      return Rect.fromLTWH(0, top, size.width, revealHeight);
    }
  }

  @override
  bool shouldReclip(_BarnDoorVerticalClipper oldClipper) {
    return oldClipper.progress != progress || oldClipper.opening != opening;
  }
}

/// Custom clipper for wipe transitions
/// Progressively reveals content from a specific direction based on alignment
class _WipeClipper extends CustomClipper<Rect> {
  final double progress; // 0.0 to 1.0
  final Alignment alignment; // Direction of wipe

  _WipeClipper({required this.progress, required this.alignment});

  @override
  Rect getClip(Size size) {
    // Wipe directions based on alignment:
    // centerLeft → wipes from left to right
    // centerRight → wipes from right to left
    // topCenter → wipes from top to bottom
    // bottomCenter → wipes from bottom to top

    if (alignment == Alignment.centerLeft) {
      // Wipe from left edge → reveal progressively to the right
      return Rect.fromLTWH(0, 0, size.width * progress, size.height);
    } else if (alignment == Alignment.centerRight) {
      // Wipe from right edge → reveal progressively to the left
      final revealWidth = size.width * progress;
      return Rect.fromLTWH(
          size.width - revealWidth, 0, revealWidth, size.height);
    } else if (alignment == Alignment.topCenter) {
      // Wipe from top edge → reveal progressively downward
      return Rect.fromLTWH(0, 0, size.width, size.height * progress);
    } else if (alignment == Alignment.bottomCenter) {
      // Wipe from bottom edge → reveal progressively upward
      final revealHeight = size.height * progress;
      return Rect.fromLTWH(
          0, size.height - revealHeight, size.width, revealHeight);
    }

    // Fallback: full reveal
    return Rect.fromLTWH(0, 0, size.width, size.height);
  }

  @override
  bool shouldReclip(_WipeClipper oldClipper) {
    return oldClipper.progress != progress || oldClipper.alignment != alignment;
  }
}

/// Custom clipper for circular reveal transitions
class _CircleRevealClipper extends CustomClipper<Rect> {
  final double progress;
  final bool reverse;

  _CircleRevealClipper({required this.progress, this.reverse = false});

  @override
  Rect getClip(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.longestSide;
    final radius = reverse ? maxRadius * progress : maxRadius * progress;

    return Rect.fromCircle(center: center, radius: radius);
  }

  @override
  bool shouldReclip(_CircleRevealClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}

/// Custom clipper for rectangle crop transition
/// Reveals content from center rectangle expanding outward
class _RectCropClipper extends CustomClipper<Rect> {
  final double progress;

  _RectCropClipper({required this.progress});

  @override
  Rect getClip(Size size) {
    // Start from small rectangle at center, expand to full size
    final revealWidth = size.width * progress;
    final revealHeight = size.height * progress;
    final left = (size.width - revealWidth) / 2;
    final top = (size.height - revealHeight) / 2;

    return Rect.fromLTWH(left, top, revealWidth, revealHeight);
  }

  @override
  bool shouldReclip(_RectCropClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}

/// Custom clipper for diagonal wipe transitions
/// Wipes from corner at 45-degree angle
class _DiagonalWipeClipper extends CustomClipper<Path> {
  final double progress;
  final DiagonalDirection direction;

  _DiagonalWipeClipper({required this.progress, required this.direction});

  @override
  Path getClip(Size size) {
    final path = Path();

    switch (direction) {
      case DiagonalDirection.topLeft:
        // Wipe from top-left corner (diagonal sweeps from top-left to bottom-right)
        // Progress 0: just corner point, Progress 1: full screen
        final sweep = (size.width + size.height) * progress;

        path.moveTo(0, 0); // Start at top-left corner

        if (sweep < size.width) {
          // Reveal top edge first
          path.lineTo(sweep, 0);
          path.lineTo(0, 0);
        } else if (sweep < size.width + size.height) {
          // Reveal right edge and bottom edge
          path.lineTo(size.width, 0);
          path.lineTo(size.width, sweep - size.width);
          path.lineTo(sweep - size.height, size.height);
          path.lineTo(0, size.height);
          path.lineTo(0, 0);
        } else {
          // Full reveal
          path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
        }
        break;

      case DiagonalDirection.topRight:
        // Wipe from top-right corner
        final sweep = (size.width + size.height) * progress;

        path.moveTo(size.width, 0); // Start at top-right corner

        if (sweep < size.width) {
          // Reveal top edge first
          path.lineTo(size.width - sweep, 0);
          path.lineTo(size.width, 0);
        } else if (sweep < size.width + size.height) {
          // Reveal left edge and bottom edge
          path.lineTo(0, 0);
          path.lineTo(0, sweep - size.width);
          path.lineTo(size.width - (sweep - size.height), size.height);
          path.lineTo(size.width, size.height);
          path.lineTo(size.width, 0);
        } else {
          // Full reveal
          path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
        }
        break;

      case DiagonalDirection.bottomLeft:
        // Wipe from bottom-left corner
        final sweep = (size.width + size.height) * progress;

        path.moveTo(0, size.height); // Start at bottom-left corner

        if (sweep < size.height) {
          // Reveal left edge first
          path.lineTo(0, size.height - sweep);
          path.lineTo(0, size.height);
        } else if (sweep < size.width + size.height) {
          // Reveal top edge and right edge
          path.lineTo(0, 0);
          path.lineTo(sweep - size.height, 0);
          path.lineTo(size.width, size.height - (sweep - size.width));
          path.lineTo(size.width, size.height);
          path.lineTo(0, size.height);
        } else {
          // Full reveal
          path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
        }
        break;

      case DiagonalDirection.bottomRight:
        // Wipe from bottom-right corner
        final sweep = (size.width + size.height) * progress;

        path.moveTo(size.width, size.height); // Start at bottom-right corner

        if (sweep < size.height) {
          // Reveal right edge first
          path.lineTo(size.width, size.height - sweep);
          path.lineTo(size.width, size.height);
        } else if (sweep < size.width + size.height) {
          // Reveal top edge and left edge
          path.lineTo(size.width, 0);
          path.lineTo(size.width - (sweep - size.height), 0);
          path.lineTo(0, size.height - (sweep - size.width));
          path.lineTo(0, size.height);
          path.lineTo(size.width, size.height);
        } else {
          // Full reveal
          path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
        }
        break;
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(_DiagonalWipeClipper oldClipper) {
    return oldClipper.progress != progress || oldClipper.direction != direction;
  }
}
