import 'package:ai_video_creator_editor/screens/project/models/transform_data.dart';
import 'package:ai_video_creator_editor/utils/performance_monitor.dart';
import 'package:flutter/material.dart';
import 'dart:math';

/// Optimized transform widget with enhanced caching and performance
class OptimizedCropTransform extends StatelessWidget {
  const OptimizedCropTransform({
    super.key,
    required this.transform,
    required this.child,
    this.shouldAnimate = true,
    this.animationDuration =
        const Duration(milliseconds: 500), // Increased from 200ms
    this.animationCurve = Curves.easeOutCubic,
  });

  final Widget child;
  final TransformData transform;
  final bool shouldAnimate;
  final Duration animationDuration;
  final Curve animationCurve;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child:
          shouldAnimate ? _buildAnimatedTransform() : _buildStaticTransform(),
    );
  }

  Widget _buildStaticTransform() {
    return Transform.rotate(
      angle: transform.rotation,
      child: Transform.scale(
        scale: transform.scale,
        child: Transform.translate(
          offset: transform.translate,
          child: child,
        ),
      ),
    );
  }

  Widget _buildAnimatedTransform() {
    return TweenAnimationBuilder<TransformData>(
      duration: animationDuration,
      curve: animationCurve,
      tween: Tween<TransformData>(
        begin: transform, // Start from current transform to eliminate animation
        end: transform,
      ),
      builder: (context, value, child) {
        return Transform.rotate(
          angle: value.rotation,
          child: Transform.scale(
            scale: value.scale,
            child: Transform.translate(
              offset: value.translate,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// Enhanced transform with rotation animation and performance monitoring
class OptimizedCropTransformWithAnimation extends StatefulWidget {
  const OptimizedCropTransformWithAnimation({
    super.key,
    required this.transform,
    required this.child,
    this.shouldAnimate = true,
    this.animationDuration =
        const Duration(milliseconds: 600), // Increased from 300ms
    this.animationCurve = Curves.easeInOut,
  });

  final Widget child;
  final TransformData transform;
  final bool shouldAnimate;
  final Duration animationDuration;
  final Curve animationCurve;

  @override
  State<OptimizedCropTransformWithAnimation> createState() =>
      _OptimizedCropTransformWithAnimationState();
}

class _OptimizedCropTransformWithAnimationState
    extends State<OptimizedCropTransformWithAnimation>
    with SingleTickerProviderStateMixin, PerformanceMonitoringMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _translateAnimation;

  TransformData _previousTransform = const TransformData();
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _setupAnimations();
    super.initState();
  }

  void _setupAnimations() {
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: widget.animationCurve,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: widget.animationCurve,
    ));

    _translateAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: widget.animationCurve,
    ));
  }

  @override
  void didUpdateWidget(OptimizedCropTransformWithAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only animate if there are actual meaningful changes
    if (widget.transform != _previousTransform &&
        widget.shouldAnimate &&
        _hasSignificantChanges(widget.transform, _previousTransform)) {
      _startAnimation();
    }

    _previousTransform = widget.transform;
  }

  /// Check if there are significant changes that warrant animation
  bool _hasSignificantChanges(
      TransformData newTransform, TransformData oldTransform) {
    // Normalize rotation values to prevent unwanted animations
    final normalizedNewRotation = _normalizeRotation(newTransform.rotation);
    final normalizedOldRotation = _normalizeRotation(oldTransform.rotation);

    // Only animate if rotation change is significant (> 0.1 radians ~ 5.7 degrees)
    if ((normalizedNewRotation - normalizedOldRotation).abs() > 0.1) {
      return true;
    }

    // Only animate if scale change is significant (> 0.05)
    if ((newTransform.scale - oldTransform.scale).abs() > 0.05) {
      return true;
    }

    // Only animate if translation change is significant (> 5 pixels)
    if ((newTransform.translate - oldTransform.translate).distance > 5.0) {
      return true;
    }

    return false;
  }

  /// Normalize rotation to prevent unwanted animations
  double _normalizeRotation(double rotation) {
    // Convert to degrees, normalize to 0-360 range, then back to radians
    final degrees = (rotation * 180 / pi) % 360;
    return degrees * pi / 180;
  }

  void _startAnimation() {
    monitorSyncOperation('_startAnimation', () {
      if (_isAnimating) {
        _animationController.stop();
      }

      // Update animation values
      _rotationAnimation = Tween<double>(
        begin: _previousTransform.rotation,
        end: widget.transform.rotation,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: widget.animationCurve,
      ));

      _scaleAnimation = Tween<double>(
        begin: _previousTransform.scale,
        end: widget.transform.scale,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: widget.animationCurve,
      ));

      _translateAnimation = Tween<Offset>(
        begin: _previousTransform.translate,
        end: widget.transform.translate,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: widget.animationCurve,
      ));

      _isAnimating = true;
      _animationController.forward().then((_) {
        _isAnimating = false;
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.shouldAnimate) {
      return OptimizedCropTransform(
        transform: widget.transform,
        child: widget.child,
        shouldAnimate: false,
      );
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.rotate(
            angle: _rotationAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.translate(
                offset: _translateAnimation.value,
                child: child,
              ),
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Zero transform data for animation initialization
extension TransformDataExtension on TransformData {
  static const TransformData zero = TransformData(
    scale: 1.0,
    rotation: 0.0,
    translate: Offset.zero,
  );
}
