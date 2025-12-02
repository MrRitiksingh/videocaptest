import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:ai_video_creator_editor/screens/project/new_editor/video_editor_provider.dart';
import 'package:ai_video_creator_editor/components/crop/crop_grid.dart';
import 'package:ai_video_creator_editor/screens/project/models/text_track_model.dart';
import 'package:ai_video_creator_editor/utils/text_auto_wrap_helper.dart';
import 'text_overlay_painter.dart';
import 'canvas_coordinate_manager.dart';
import 'canvas_font_manager.dart';
import 'text_rotation_manager.dart';

/// Optimized preview container that uses canvas for text overlays
class OptimizedPreviewContainer extends StatefulWidget {
  final VideoEditorProvider provider;
  final Size containerSize;
  final GlobalKey canvasKey;

  const OptimizedPreviewContainer({
    super.key,
    required this.provider,
    required this.containerSize,
    required this.canvasKey,
  });

  @override
  State<OptimizedPreviewContainer> createState() =>
      _OptimizedPreviewContainerState();
}

class _OptimizedPreviewContainerState extends State<OptimizedPreviewContainer>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  // Cache canvas painter to avoid recreation
  late TextOverlayPainter _cachedPainter;
  Size? _lastContainerSize;
  List<TextTrackModel>? _lastTextTracks;
  Rect? _lastCropRect;
  Offset? _lastGapOffset;

  // Text position remapping state for crop changes
  Map<String, Offset> _originalTextPositions = {};
  bool _hasRemappedTextPositions = false;

  // ✅ NEW: Video rotation state tracking
  int? _lastVideoRotation;
  bool _hasRemappedTextPositionsForRotation = false;
  Map<String, Offset> _originalTextPositionsForRotation =
      {}; // ✅ NEW: Missing variable

  // Rotation state management
  TextTrackModel? _rotatingTrack;
  double? _tempRotation;
  Timer? _throttleTimer;
  late AnimationController _rotationAnimController;
  late Animation<double> _rotationAnim;
  Offset? _cachedRotationCenter;

  // Two-finger rotation state
  TextTrackModel? _scalingTrack;
  double? _initialRotation;
  double? _initialScale;
  Offset? _scaleCenter;

  // Enhanced gesture state for smoother experience
  Offset? _lastFocalPoint;
  DateTime? _lastUpdateTime;
  Offset? _gestureVelocity;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cachedPainter = TextOverlayPainter(
      textTracks: [],
      cropRect: null,
      currentTime: 0,
      containerSize: Size.zero,
      videoSize: Size.zero,
      gapOffset: Offset.zero,
      isPreview: true,
      localDragPositions: {},
      rotatingTrack: null,
      tempRotation: null,
      selectedTextTrackIndex: -1,
      videoRotation: 0,
    );

    // Initialize rotation animation controller
    _rotationAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _rotationAnim =
        Tween<double>(begin: 0, end: 0).animate(_rotationAnimController);

    // Initialize crop state and handle existing crop if any
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCropState();

      // ✅ NEW: Initialize video rotation state
      _initializeVideoRotationState();
    });
  }

  /// Initialize crop state and handle existing crop if any
  void _initializeCropState() {
    final currentCrop = widget.provider.cropRect;
    if (currentCrop != null) {
      print('=== Initializing with Existing Crop ===');
      print('Existing crop: $currentCrop');

      // Store original positions for existing text tracks
      _storeOriginalTextPositions();

      // Handle any existing text tracks that might be outside the crop bounds
      if (widget.provider.textTracks.isNotEmpty) {
        _handleExistingTextTracksWithCrop(currentCrop);
      }

      print('=== End Initializing with Existing Crop ===');
    }
  }

  /// ✅ NEW: Initialize video rotation state and handle existing rotation if any
  void _initializeVideoRotationState() {
    final currentRotation =
        widget.provider.videoEditorController?.rotation ?? 0;
    if (currentRotation != 0) {
      print('=== Initializing with Existing Video Rotation ===');
      print('Existing rotation: ${currentRotation}°');

      // Store original positions for existing text tracks
      _storeOriginalTextPositionsForRotation();

      // Handle any existing text tracks that might be outside the rotated bounds
      if (widget.provider.textTracks.isNotEmpty) {
        _handleExistingTextTracksWithRotation(currentRotation);
      }

      print('=== End Initializing with Existing Video Rotation ===');
    }
  }

  /// ✅ NEW: Handle existing text tracks when initializing with video rotation
  void _handleExistingTextTracksWithRotation(int rotation) {
    print('=== Handling Existing Text Tracks with Video Rotation ===');

    final videoSize = widget.provider.videoEditorController?.video.value.size;
    if (videoSize == null) {
      print('Error: Video size not available during rotation initialization');
      return;
    }

    // Calculate the rotated video area boundaries
    final rotatedVideoArea = _calculateRotatedVideoArea(rotation);
    print('Rotated video area: $rotatedVideoArea');

    for (int i = 0; i < widget.provider.textTracks.length; i++) {
      final track = widget.provider.textTracks[i];
      print('--- Checking existing track: "${track.text}" ---');
      print('Current position: (${track.position.dx}, ${track.position.dy})');

      // Check if the track's position is within bounds
      if (!_isPositionWithinBounds(track.position, rotatedVideoArea, track)) {
        print('Track position is outside rotated bounds - repositioning');

        // Calculate a good position within the rotated area
        final newPosition =
            _calculateTopLeftFallbackPosition(rotatedVideoArea, track);
        print('New position: (${newPosition.dx}, ${newPosition.dy})');

        // Update the track position
        _updateTextTrackPosition(i, newPosition);
      } else {
        print(
            'Track position is within rotated bounds - no repositioning needed');
      }
    }

    print('=== End Handling Existing Text Tracks with Video Rotation ===');
  }

  /// Handle existing text tracks when initializing with a crop
  void _handleExistingTextTracksWithCrop(Rect cropRect) {
    print('=== Handling Existing Text Tracks with Crop ===');

    final videoSize = widget.provider.videoEditorController?.video.value.size;
    if (videoSize == null) {
      print('Error: Video size not available during initialization');
      return;
    }

    // Calculate the cropped video area boundaries with proper mapping
    final croppedVideoArea = _calculateCroppedVideoAreaWithMapping(cropRect);
    print('Cropped video area: $croppedVideoArea');

    for (int i = 0; i < widget.provider.textTracks.length; i++) {
      final track = widget.provider.textTracks[i];
      print('--- Checking existing track: "${track.text}" ---');
      print('Current position: (${track.position.dx}, ${track.position.dy})');

      // Check if the track's position is within bounds
      if (!_isPositionWithinBounds(track.position, croppedVideoArea, track)) {
        print('Track position is outside cropped bounds - repositioning');

        // Calculate a good position within the cropped area
        final newPosition =
            _calculateTopLeftFallbackPosition(croppedVideoArea, track);
        print('New position: (${newPosition.dx}, ${newPosition.dy})');

        // Update the track position
        _updateTextTrackPosition(i, newPosition);
      } else {
        print(
            'Track position is within cropped bounds - no repositioning needed');
      }
    }

    print('=== End Handling Existing Text Tracks with Crop ===');
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    _rotationAnimController.dispose();

    // Clean up text remapping state
    _originalTextPositions.clear();
    _hasRemappedTextPositions = false;

    // ✅ NEW: Clean up rotation remapping state
    _originalTextPositionsForRotation.clear();
    _hasRemappedTextPositionsForRotation = false;

    super.dispose();
  }

  bool _shouldRepaint() {
    final currentSize = widget.containerSize;
    final currentTracks = widget.provider.textTracks;
    final currentCrop = widget.provider.cropRect;
    final currentGapOffset = _calculateGapOffset();

    // ✅ NEW: Check if video rotation has changed
    final currentVideoRotation =
        widget.provider.videoEditorController?.rotation ?? 0;

    // ✅ DEBUG: Always log rotation values to see what's happening
    print('=== Rotation Detection Debug ===');
    print('Last video rotation: $_lastVideoRotation');
    print('Current video rotation: $currentVideoRotation');
    print('Provider rotation: ${widget.provider.rotation}');
    print(
        'Controller rotation: ${widget.provider.videoEditorController?.rotation}');
    print('Rotation changed: ${_lastVideoRotation != currentVideoRotation}');
    print('=== End Rotation Detection Debug ===');

    if (_lastVideoRotation != currentVideoRotation) {
      _handleVideoRotationChange(_lastVideoRotation, currentVideoRotation);
    }

    // Check if crop has changed and handle text position remapping
    if (_lastCropRect != currentCrop) {
      _handleCropChange(_lastCropRect, currentCrop);
    }

    // Check for new text tracks and handle them if crop is applied
    if (_lastTextTracks != null &&
        currentTracks.length > _lastTextTracks!.length) {
      _handleNewTextTracksAdded(_lastTextTracks!, currentTracks);
    }

    // Check if existing text tracks have moved (user interaction)
    if (_lastTextTracks != null &&
        currentTracks.length == _lastTextTracks!.length) {
      _checkForTextPositionChanges(_lastTextTracks!, currentTracks);
    }

    // Always repaint if we have local drag positions for smooth dragging
    if (_localDragPositions.isNotEmpty) return true;

    // Always repaint if we're scaling/rotating with unified gestures
    if (_scalingTrack != null) return true;

    // Always repaint if we have temporary rotation for smooth rotation
    if (_tempRotation != null) return true;

    // Always repaint if we just remapped text positions
    if (_hasRemappedTextPositions) return true;

    // ✅ NEW: Always repaint if we just remapped text positions for rotation
    if (_hasRemappedTextPositionsForRotation) return true;

    return _lastContainerSize != currentSize ||
        _lastTextTracks != currentTracks ||
        _lastCropRect != currentCrop ||
        _lastGapOffset != currentGapOffset ||
        _lastVideoRotation !=
            currentVideoRotation; // ✅ NEW: Include video rotation
  }

  void _updatePainter() {
    if (_shouldRepaint()) {
      // Create text tracks with local drag positions for smooth dragging
      final textTracksWithLocalPositions =
          _createTextTracksWithLocalPositions();

      _cachedPainter = TextOverlayPainter(
        textTracks: textTracksWithLocalPositions,
        cropRect: widget.provider.cropRect,
        currentTime: widget.provider.currentVideoTime,
        containerSize: widget.containerSize,
        videoSize: widget.provider.videoEditorController?.video.value.size ??
            Size.zero,
        gapOffset: _calculateGapOffset(),
        isPreview: true,
        localDragPositions: _localDragPositions,
        rotatingTrack:
            _rotatingTrack ?? _scalingTrack, // Support both rotation modes
        tempRotation: _tempRotation,
        selectedTextTrackIndex: widget.provider.selectedTextTrackIndex,
        videoRotation: widget.provider.videoEditorController?.rotation ?? 0,
      );

      _lastContainerSize = widget.containerSize;
      _lastTextTracks = List.from(widget.provider.textTracks);
      _lastCropRect = widget.provider.cropRect;
      _lastGapOffset = _calculateGapOffset();

      // Reset remapping flag after painter update
      _hasRemappedTextPositions = false;

      // ✅ NEW: Update video rotation state and reset rotation remapping flag
      _lastVideoRotation = widget.provider.videoEditorController?.rotation ?? 0;
      _hasRemappedTextPositionsForRotation = false;
    }
  }

  /// Handle crop changes by remapping text positions
  void _handleCropChange(Rect? oldCrop, Rect? newCrop) {
    print('=== Crop Change Detection ===');
    print('Old crop: $oldCrop');
    print('New crop: $newCrop');
    print('Text tracks count: ${widget.provider.textTracks.length}');

    // If this is the first time (no previous crop), store original positions
    if (oldCrop == null && !_hasRemappedTextPositions) {
      _storeOriginalTextPositions();
    }
    // If we're applying a new crop (changing from one crop to another),
    // update the stored positions to use current text positions as the new reference
    else if (oldCrop != null && newCrop != null) {
      print('Updating stored positions for new crop operation');
      _updateStoredTextPositions();
    }

    // If crop is being applied and we have original positions
    if (newCrop != null && _originalTextPositions.isNotEmpty) {
      _remapTextPositionsForCrop(newCrop);
    }
    // If crop is being removed, restore original positions
    else if (newCrop == null && _originalTextPositions.isNotEmpty) {
      _restoreOriginalTextPositions();
    }

    print('=== End Crop Change Detection ===');
  }

  /// ✅ NEW: Handle video rotation changes by remapping text positions
  void _handleVideoRotationChange(int? oldRotation, int newRotation) {
    print('=== Video Rotation Change Detection ===');
    print('Old rotation: ${oldRotation ?? 'none'}°');
    print('New rotation: ${newRotation}°');
    print('Text tracks count: ${widget.provider.textTracks.length}');

    // If this is the first time (no previous rotation), store original positions
    if (oldRotation == null && !_hasRemappedTextPositionsForRotation) {
      _storeOriginalTextPositionsForRotation();
    }
    // If we're changing rotation, update the stored positions
    else if (oldRotation != null) {
      print('Updating stored positions for new rotation');
      _updateStoredTextPositionsForRotation();
    }

    // Remap text positions for the new rotation
    if (_originalTextPositionsForRotation.isNotEmpty) {
      _remapTextPositionsForVideoRotation(newRotation);
    }

    print('=== End Video Rotation Change Detection ===');
  }

  /// Store original text positions before any crop is applied
  void _storeOriginalTextPositions() {
    print('=== Storing Original Text Positions ===');
    _originalTextPositions.clear();

    for (final track in widget.provider.textTracks) {
      _originalTextPositions[track.id] = track.position;
      print(
          'Stored position for "${track.text}": (${track.position.dx}, ${track.position.dy})');
    }

    print('Stored ${_originalTextPositions.length} text positions');
    print('=== End Storing Original Text Positions ===');
  }

  /// Update stored text positions to use current positions as the new reference
  void _updateStoredTextPositions() {
    print('=== Updating Stored Text Positions ===');

    for (final track in widget.provider.textTracks) {
      final oldPosition = _originalTextPositions[track.id];
      final newPosition = track.position;

      if (oldPosition != null) {
        print('Updating stored position for "${track.text}":');
        print('  Old stored: (${oldPosition.dx}, ${oldPosition.dy})');
        print('  New current: (${newPosition.dx}, ${newPosition.dy})');
      } else {
        print(
            'Adding new stored position for "${track.text}": (${newPosition.dx}, ${newPosition.dy})');
      }

      _originalTextPositions[track.id] = newPosition;
    }

    print('Updated ${_originalTextPositions.length} text positions');
    print('=== End Updating Stored Text Positions ===');
  }

  /// Remap text positions to fit within the new cropped area
  void _remapTextPositionsForCrop(Rect newCrop) {
    print('=== Remapping Text Positions for Crop ===');
    print('New crop: $newCrop');

    final videoSize = widget.provider.videoEditorController?.video.value.size;
    if (videoSize == null) {
      print('Error: Video size not available');
      return;
    }

    // Calculate the new cropped video area boundaries with proper mapping
    final croppedVideoArea = _calculateCroppedVideoAreaWithMapping(newCrop);
    print('Cropped video area: $croppedVideoArea');

    for (int i = 0; i < widget.provider.textTracks.length; i++) {
      final track = widget.provider.textTracks[i];
      final originalPosition = _originalTextPositions[track.id];

      if (originalPosition != null) {
        print('--- Remapping track: "${track.text}" ---');
        print(
            'Original position: (${originalPosition.dx}, ${originalPosition.dy})');

        // Calculate proportional position within the cropped area using crop-aware mapping
        final remappedPosition = _calculateProportionalPositionWithCropMapping(
          originalPosition: originalPosition,
          oldVideoArea: _getFullVideoArea(),
          newVideoArea: croppedVideoArea,
          cropRect: newCrop,
        );

        print(
            'Proportional position: (${remappedPosition.dx}, ${remappedPosition.dy})');

        // Check if the proportional position is within bounds
        if (_isPositionWithinBounds(
            remappedPosition, croppedVideoArea, track)) {
          print('Proportional position is within bounds - using it');
          _updateTextTrackPosition(i, remappedPosition);
        } else {
          print(
              'Proportional position is outside bounds - using top-left fallback');
          final fallbackPosition =
              _calculateTopLeftFallbackPosition(croppedVideoArea, track);
          print(
              'Fallback position: (${fallbackPosition.dx}, ${fallbackPosition.dy})');
          _updateTextTrackPosition(i, fallbackPosition);
        }
      }
    }

    _hasRemappedTextPositions = true;
    print('=== End Remapping Text Positions for Crop ===');
  }

  /// Restore original text positions when crop is removed
  void _restoreOriginalTextPositions() {
    print('=== Restoring Original Text Positions ===');

    for (int i = 0; i < widget.provider.textTracks.length; i++) {
      final track = widget.provider.textTracks[i];
      final originalPosition = _originalTextPositions[track.id];

      if (originalPosition != null) {
        print(
            'Restoring position for "${track.text}": (${originalPosition.dx}, ${originalPosition.dy})');
        _updateTextTrackPosition(i, originalPosition);
      }
    }

    _hasRemappedTextPositions = true;
    print('=== End Restoring Original Text Positions ===');
  }

  /// Calculate the full video area boundaries (no crop)
  Rect _getFullVideoArea() {
    final videoSize = widget.provider.videoEditorController?.video.value.size;
    if (videoSize == null) return Rect.zero;

    // ✅ FIXED: Check if video is rotated and use rotation-aware calculation
    final currentRotation =
        widget.provider.videoEditorController?.rotation ?? 0;

    // ✅ DEBUG: Always log which path we're taking
    print('=== _getFullVideoArea Debug ===');
    print('Current rotation: $currentRotation');
    print('Is rotated: ${currentRotation != 0}');
    print('=== End _getFullVideoArea Debug ===');

    if (currentRotation != 0) {
      // ✅ NEW: If video is rotated, use rotation-aware calculation
      print('=== Full Video Area: Using Rotation-Aware Calculation ===');
      final rotatedArea = _calculateRotatedVideoArea(currentRotation);
      print('=== End Full Video Area: Rotation-Aware Calculation ===');
      return rotatedArea;
    } else {
      // ✅ Use the new method that considers current state (crop, etc.) when no rotation
      print(
          '=== Full Video Area: Using Current Display Area (No Rotation) ===');
      final currentArea = _getCurrentVideoDisplayArea();
      print('=== End Full Video Area: Current Display Area ===');
      return currentArea;
    }
  }

  /// Calculate the cropped video area boundaries with proper crop rectangle mapping
  Rect _calculateCroppedVideoAreaWithMapping(Rect cropRect) {
    final videoSize = widget.provider.videoEditorController?.video.value.size;
    if (videoSize == null) return Rect.zero;

    print('=== Cropped Video Area Calculation ===');
    print('Video size: ${videoSize.width} x ${videoSize.height}');
    print(
        'Crop rect (video coordinates): ${cropRect.left}, ${cropRect.top}, ${cropRect.right}, ${cropRect.bottom}');
    print(
        'Container size: ${widget.containerSize.width} x ${widget.containerSize.height}');

    // First, calculate how the original video fits in the container
    final originalFitting = CanvasCoordinateManager.calculateContainerFitting(
      videoWidth: videoSize.width,
      videoHeight: videoSize.height,
      containerWidth: widget.containerSize.width,
      containerHeight: widget.containerSize.height,
    );

    final originalPreviewWidth = originalFitting['actualPreviewWidth']!;
    final originalPreviewHeight = originalFitting['actualPreviewHeight']!;
    final originalGapLeft = originalFitting['gapLeft']!;
    final originalGapTop = originalFitting['gapTop']!;

    print(
        'Original preview: ${originalPreviewWidth} x ${originalPreviewHeight}');
    print('Original gaps: left=${originalGapLeft}, top=${originalGapTop}');

    // The crop rectangle is in video coordinates (0.0 to 1.0 or actual video pixels)
    // We need to map this to the preview area

    // Calculate the scale factors from video to preview
    final scaleX = originalPreviewWidth / videoSize.width;
    final scaleY = originalPreviewHeight / videoSize.height;

    print('Scale factors: X=$scaleX, Y=$scaleY');

    // Map the crop rectangle from video coordinates to preview coordinates
    final cropLeftInPreview = originalGapLeft + (cropRect.left * scaleX);
    final cropTopInPreview = originalGapTop + (cropRect.top * scaleY);
    final cropWidthInPreview = cropRect.width * scaleX;
    final cropHeightInPreview = cropRect.height * scaleY;

    print(
        'Crop in preview: left=${cropLeftInPreview.toStringAsFixed(2)}, top=${cropTopInPreview.toStringAsFixed(2)}');
    print(
        'Crop size in preview: ${cropWidthInPreview.toStringAsFixed(2)} x ${cropHeightInPreview.toStringAsFixed(2)}');

    // Now we need to fit this cropped area within the original preview area
    // The cropped video gets fitted with pillarbox/letterbox as needed
    final cropAspectRatio = cropWidthInPreview / cropHeightInPreview;
    final videoDisplayAspectRatio =
        originalPreviewWidth / originalPreviewHeight;

    double finalCropWidth, finalCropHeight, finalCropLeft, finalCropTop;

    if (cropAspectRatio > videoDisplayAspectRatio) {
      // Crop is wider - fit width, letterbox top/bottom within video area
      finalCropWidth = originalPreviewWidth;
      finalCropHeight = originalPreviewWidth / cropAspectRatio;
      finalCropTop =
          originalGapTop + (originalPreviewHeight - finalCropHeight) / 2.0;
      finalCropLeft = originalGapLeft;
    } else {
      // Crop is taller - fit height, letterbox left/right within video area
      finalCropHeight = originalPreviewHeight;
      finalCropWidth = originalPreviewHeight * cropAspectRatio;
      finalCropLeft =
          originalGapLeft + (originalPreviewWidth - finalCropWidth) / 2.0;
      finalCropTop = originalGapTop;
    }

    print(
        'Final crop area: left=${finalCropLeft.toStringAsFixed(2)}, top=${finalCropTop.toStringAsFixed(2)}');
    print(
        'Final crop size: ${finalCropWidth.toStringAsFixed(2)} x ${finalCropHeight.toStringAsFixed(2)}');
    print('=== End Cropped Video Area Calculation ===');

    return Rect.fromLTWH(
      finalCropLeft,
      finalCropTop,
      finalCropWidth,
      finalCropHeight,
    );
  }

  /// Calculate proportional position within the new cropped area with proper crop coordinate mapping
  Offset _calculateProportionalPositionWithCropMapping({
    required Offset originalPosition,
    required Rect oldVideoArea,
    required Rect newVideoArea,
    required Rect cropRect,
  }) {
    print('=== Crop-Aware Proportional Position Calculation ===');
    print(
        'Original position: (${originalPosition.dx}, ${originalPosition.dy})');
    print(
        'Old video area: ${oldVideoArea.left}, ${oldVideoArea.top}, ${oldVideoArea.right}, ${oldVideoArea.bottom}');
    print(
        'New video area: ${newVideoArea.left}, ${newVideoArea.top}, ${newVideoArea.right}, ${newVideoArea.bottom}');
    print(
        'Crop rect: ${cropRect.left}, ${cropRect.top}, ${cropRect.right}, ${cropRect.bottom}');

    // The key insight: the crop rectangle represents a portion of the original video
    // We need to map the text position from the original video space to the cropped video space

    // Step 1: Convert original position to percentage within the full video area
    final percentX =
        (originalPosition.dx - oldVideoArea.left) / oldVideoArea.width;
    final percentY =
        (originalPosition.dy - oldVideoArea.top) / oldVideoArea.height;

    print(
        'Position percentages: X=${(percentX * 100).toStringAsFixed(2)}%, Y=${(percentY * 100).toStringAsFixed(2)}%');

    // Step 2: Check if the position is within the crop area
    // If the position is outside the crop area, we need to adjust it
    final isWithinCrop = percentX >= 0.0 &&
        percentX <= 1.0 &&
        percentY >= 0.0 &&
        percentY <= 1.0;

    if (!isWithinCrop) {
      print('Position is outside crop area - adjusting to crop boundaries');
      // Clamp to crop boundaries
      final clampedPercentX = percentX.clamp(0.0, 1.0);
      final clampedPercentY = percentY.clamp(0.0, 1.0);
      print(
          'Clamped percentages: X=${(clampedPercentX * 100).toStringAsFixed(2)}%, Y=${(clampedPercentY * 100).toStringAsFixed(2)}%');

      // Apply clamped percentages to the new cropped area
      final newX = newVideoArea.left + (clampedPercentX * newVideoArea.width);
      final newY = newVideoArea.top + (clampedPercentY * newVideoArea.height);

      print(
          'Clamped new position: (${newX.toStringAsFixed(2)}, ${newY.toStringAsFixed(2)})');
      print('=== End Crop-Aware Proportional Position Calculation ===');
      return Offset(newX, newY);
    }

    // Step 3: Apply the same percentage to the new cropped area
    final newX = newVideoArea.left + (percentX * newVideoArea.width);
    final newY = newVideoArea.top + (percentY * newVideoArea.height);

    print(
        'Calculated new position: (${newX.toStringAsFixed(2)}, ${newY.toStringAsFixed(2)})');
    print('=== End Crop-Aware Proportional Position Calculation ===');

    return Offset(newX, newY);
  }

  /// Check if a position is within the bounds of the cropped video area
  bool _isPositionWithinBounds(
      Offset position, Rect videoArea, TextTrackModel track) {
    final textDimensions = _calculateTextDimensions(track);

    // Check if the text would fit within the video area bounds
    final textRight = position.dx + textDimensions.width;
    final textBottom = position.dy + textDimensions.height;

    return position.dx >= videoArea.left &&
        position.dy >= videoArea.top &&
        textRight <= videoArea.right &&
        textBottom <= videoArea.bottom;
  }

  /// Calculate top-left fallback position within the cropped video area
  Offset _calculateTopLeftFallbackPosition(
      Rect videoArea, TextTrackModel track) {
    final textDimensions = _calculateTextDimensions(track);

    // ✅ ADDED: Debug logging to identify the issue
    print('=== Top-Left Fallback Position Debug ===');
    print(
        'Video area: ${videoArea.left}, ${videoArea.top}, ${videoArea.right}, ${videoArea.bottom}');
    print('Video area dimensions: ${videoArea.width} x ${videoArea.height}');
    print(
        'Text dimensions: ${textDimensions.width} x ${textDimensions.height}');
    print('Track text: "${track.text}"');

    // ✅ FIXED: Validate video area dimensions before clamping
    if (videoArea.width <= 0 || videoArea.height <= 0) {
      print('ERROR: Invalid video area dimensions - using safe fallback');
      return Offset(10.0, 10.0); // Safe fallback position
    }

    // Position at top-left with a small offset for visibility
    final offset = 10.0;
    final x = videoArea.left + offset;
    final y = videoArea.top + offset;

    // ✅ FIXED: Ensure clamp bounds are valid (lower <= upper)
    final minX = videoArea.left;
    final maxX = videoArea.right - textDimensions.width;
    final minY = videoArea.top;
    final maxY = videoArea.bottom - textDimensions.height;

    print('Clamp bounds - X: $minX to $maxX, Y: $minY to $maxY');

    // Validate clamp bounds
    if (minX > maxX) {
      print('ERROR: Invalid X clamp bounds (min > max) - using safe fallback');
      return Offset(videoArea.left + offset, videoArea.top + offset);
    }
    if (minY > maxY) {
      print('ERROR: Invalid Y clamp bounds (min > max) - using safe fallback');
      return Offset(videoArea.left + offset, videoArea.top + offset);
    }

    // Ensure the text doesn't extend beyond the right or bottom boundaries
    final adjustedX = x.clamp(minX, maxX);
    final adjustedY = y.clamp(minY, maxY);

    print(
        'Final adjusted position: (${adjustedX.toStringAsFixed(2)}, ${adjustedY.toStringAsFixed(2)})');
    print('=== End Top-Left Fallback Position Debug ===');

    return Offset(adjustedX, adjustedY);
  }

  /// Safely update a text track position
  void _updateTextTrackPosition(int index, Offset newPosition) {
    if (index >= 0 && index < widget.provider.textTracks.length) {
      final track = widget.provider.textTracks[index];
      final updatedTrack = track.copyWith(position: newPosition);
      widget.provider.updateTextTrackModel(index, updatedTrack);
      print(
          'Updated track "${track.text}" to position: (${newPosition.dx}, ${newPosition.dy})');
    } else {
      print('Warning: Invalid track index $index for position update');
    }
  }

  /// Handle new text tracks that are added after crop is applied
  void _handleNewTextTrackAdded(TextTrackModel newTrack) {
    final currentCrop = widget.provider.cropRect;
    if (currentCrop != null) {
      print('=== Handling New Text Track Added with Crop ===');
      print('New track: "${newTrack.text}"');
      print('Current crop: $currentCrop');

      // Calculate the cropped video area boundaries with proper mapping
      final croppedVideoArea =
          _calculateCroppedVideoAreaWithMapping(currentCrop);
      print('Cropped video area: $croppedVideoArea');

      // Check if the new track's position is within bounds
      if (!_isPositionWithinBounds(
          newTrack.position, croppedVideoArea, newTrack)) {
        print('New track position is outside cropped bounds - repositioning');

        // Calculate a good position within the cropped area
        final newPosition =
            _calculateTopLeftFallbackPosition(croppedVideoArea, newTrack);
        print('New position: (${newPosition.dx}, ${newPosition.dy})');

        // Update the track position
        final index = widget.provider.textTracks.indexOf(newTrack);
        if (index >= 0) {
          _updateTextTrackPosition(index, newPosition);
        }
      } else {
        print(
            'New track position is within cropped bounds - no repositioning needed');
      }

      print('=== End Handling New Text Track Added with Crop ===');
    }
  }

  /// Handle multiple new text tracks that are added after crop is applied
  void _handleNewTextTracksAdded(
      List<TextTrackModel> oldTracks, List<TextTrackModel> newTracks) {
    print('=== Handling New Text Tracks Added ===');
    print('Old tracks count: ${oldTracks.length}');
    print('New tracks count: ${newTracks.length}');

    // Find new tracks by comparing IDs
    final oldTrackIds = oldTracks.map((track) => track.id).toSet();
    final newTracksList =
        newTracks.where((track) => !oldTrackIds.contains(track.id)).toList();

    print('Found ${newTracksList.length} new tracks');

    // Handle each new track
    for (final newTrack in newTracksList) {
      _handleNewTextTrackAdded(newTrack);
    }

    print('=== End Handling New Text Tracks Added ===');
  }

  /// Check if existing text tracks have moved due to user interaction
  void _checkForTextPositionChanges(
      List<TextTrackModel> oldTracks, List<TextTrackModel> newTracks) {
    // Only check if we have stored positions (meaning a crop was previously applied)
    if (_originalTextPositions.isEmpty) return;

    bool hasPositionChanges = false;

    for (int i = 0; i < oldTracks.length; i++) {
      final oldTrack = oldTracks[i];
      final newTrack = newTracks[i];

      // Check if position has changed
      if (oldTrack.position != newTrack.position) {
        if (!hasPositionChanges) {
          print('=== Detecting Text Position Changes ===');
          hasPositionChanges = true;
        }

        print('Track "${newTrack.text}" moved:');
        print(
            '  Old position: (${oldTrack.position.dx}, ${oldTrack.position.dy})');
        print(
            '  New position: (${newTrack.position.dx}, ${newTrack.position.dy})');

        // Update the stored position to use the new position as the reference
        _originalTextPositions[newTrack.id] = newTrack.position;
      }
    }

    if (hasPositionChanges) {
      print(
          'Updated stored positions for ${_originalTextPositions.length} tracks');
      print('=== End Detecting Text Position Changes ===');
    }
  }

  /// Create text tracks with both local drag positions and local rotation for smoother visual feedback
  List<TextTrackModel> _createTextTracksWithLocalPositions() {
    return widget.provider.textTracks.map((track) {
      final localPosition = _localDragPositions[track.id];
      final isCurrentlyScaling = _scalingTrack?.id == track.id;
      final localRotation = isCurrentlyScaling ? _tempRotation : null;

      if (localPosition != null || localRotation != null) {
        // Return a copy with local changes for smooth visual feedback
        return track.copyWith(
          position: localPosition ?? track.position,
          rotation: localRotation ?? track.rotation,
        );
      }
      return track;
    }).toList();
  }

  /// Apply smooth easing to gesture updates for better visual feedback
  Offset _applySmoothEasing(Offset current, Offset target, double factor) {
    return Offset(
      current.dx + (target.dx - current.dx) * factor,
      current.dy + (target.dy - current.dy) * factor,
    );
  }

  /// Normalize rotation values to 0-360 degree range
  double _normalizeRotation(double rotation) {
    // Handle negative values by adding 360 until positive
    while (rotation < 0) {
      rotation += 360;
    }

    // Handle values > 360 by taking modulo
    rotation = rotation % 360;

    // Ensure we don't have -0.0 (which can happen with floating point math)
    if (rotation == 0 && rotation.isNegative) {
      rotation = 0;
    }

    return rotation;
  }

  /// Safely get the index of a track in the provider's list
  int? _getTrackIndex(TextTrackModel track) {
    final index = widget.provider.textTracks.indexOf(track);
    return index >= 0 ? index : null;
  }

  /// Safely update a text track if it still exists in the provider's list
  bool _safeUpdateTextTrack(TextTrackModel track, TextTrackModel updatedTrack) {
    final index = _getTrackIndex(track);
    if (index != null) {
      widget.provider.updateTextTrackModel(index, updatedTrack);
      return true;
    } else {
      print(
          'Warning: Track no longer exists in provider list, skipping update');
      return false;
    }
  }

  Offset _calculateGapOffset() {
    final videoSize = widget.provider.videoEditorController?.video.value.size;
    if (videoSize == null) return Offset.zero;

    // ✅ NEW: Get current video rotation
    final videoRotation = widget.provider.videoEditorController?.rotation ?? 0;

    // ✅ ADDED: Debug logging for rotation detection
    print('=== Rotation Detection Debug ===');
    print('Provider rotation: ${widget.provider.rotation}');
    print(
        'Controller rotation: ${widget.provider.videoEditorController?.rotation}');
    print('Final rotation value: $videoRotation');
    print('=== End Rotation Detection Debug ===');

    // Debug logging for landscape video issues
    final isLandscape = videoSize.width > videoSize.height;
    if (isLandscape) {
      print('=== Landscape Video Gap Offset Debug ===');
      print('Video size: ${videoSize.width} x ${videoSize.height}');
      print('Video rotation: ${videoRotation}°'); // ✅ NEW: Log rotation
      print(
          'Container size: ${widget.containerSize.width} x ${widget.containerSize.height}');
      print('Crop rect: ${widget.provider.cropRect}');
    }

    final cropRect = widget.provider.cropRect;
    Map<String, double> containerFitting;

    if (cropRect != null) {
      // ✅ FIXED: Use crop-adjusted fitting when crop is applied
      containerFitting =
          CanvasCoordinateManager.calculateCropAdjustedContainerFitting(
        videoWidth: videoSize.width,
        videoHeight: videoSize.height,
        containerWidth: widget.containerSize.width,
        containerHeight: widget.containerSize.height,
        cropRect: cropRect,
      );

      // ✅ NEW: If we also have rotation, we need to apply rotation to the crop-adjusted area
      if (videoRotation != 0) {
        print('=== Gap Offset: Crop + Rotation Mode ===');

        // Get the base crop-adjusted area
        final basePreviewWidth = containerFitting['actualPreviewWidth']!;
        final basePreviewHeight = containerFitting['actualPreviewHeight']!;
        final baseGapLeft = containerFitting['gapLeft']!;
        final baseGapTop = containerFitting['gapTop']!;

        // Apply rotation to get the final rotated crop area
        final baseVideoArea = Rect.fromLTWH(
            baseGapLeft, baseGapTop, basePreviewWidth, basePreviewHeight);
        final rotatedVideoArea =
            _applyRotationToVideoArea(baseVideoArea, videoRotation);

        // Use the rotated area for gap offset
        containerFitting = {
          'actualPreviewWidth': rotatedVideoArea.width,
          'actualPreviewHeight': rotatedVideoArea.height,
          'gapLeft': rotatedVideoArea.left,
          'gapTop': rotatedVideoArea.top,
        };

        print('Base crop area: ${basePreviewWidth} x ${basePreviewHeight}');
        print('Base gaps: left=${baseGapLeft}, top=${baseGapTop}');
        print(
            'Final rotated area: ${rotatedVideoArea.width} x ${rotatedVideoArea.height}');
        print(
            'Final rotated gaps: left=${rotatedVideoArea.left}, top=${rotatedVideoArea.top}');
        print('=== End Gap Offset: Crop + Rotation Mode ===');
      }
    } else {
      // ✅ FIXED: Check if video is rotated and use rotation-aware calculation
      if (videoRotation != 0) {
        print('=== Gap Offset: Using Rotated Video Area ===');
        // ✅ NEW: Get the rotated video area for proper gap calculation
        final rotatedVideoArea = _calculateRotatedVideoArea(videoRotation);
        containerFitting = {
          'actualPreviewWidth': rotatedVideoArea.width,
          'actualPreviewHeight': rotatedVideoArea.height,
          'gapLeft': rotatedVideoArea.left,
          'gapTop': rotatedVideoArea.top,
        };
        print('=== End Gap Offset: Rotated Video Area ===');
      } else {
        // ✅ Use the new method that considers current state (crop, etc.) when no rotation
        final currentVideoArea = _getCurrentVideoDisplayArea();
        containerFitting = {
          'actualPreviewWidth': currentVideoArea.width,
          'actualPreviewHeight': currentVideoArea.height,
          'gapLeft': currentVideoArea.left,
          'gapTop': currentVideoArea.top,
        };
      }
    }

    final gapOffset = Offset(
      containerFitting['gapLeft']!,
      containerFitting['gapTop']!,
    );

    if (isLandscape) {
      print('Container fitting: $containerFitting');
      print('Calculated gap offset: (${gapOffset.dx}, ${gapOffset.dy})');
      print('=== End Landscape Video Gap Offset Debug ===');
    }

    return gapOffset;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Update painter if needed
    _updatePainter();

    return Container(
      width: widget.containerSize.width,
      height: widget.containerSize.height,
      color: Colors.black,
      child: Stack(
        children: [
          // Video preview with existing crop system
          _buildConstrainedVideoPreview(),

          // Canvas text overlays with unified scale gesture support
          Positioned.fill(
            child: GestureDetector(
              onTapDown: _handleCanvasTap,
              // Unified gesture handling:
              // - Single finger: tap to select
              // - Single finger: drag to move text
              // - Two fingers: rotate text naturally
              onScaleStart: _handleScaleStart,
              onScaleUpdate: _handleScaleUpdate,
              onScaleEnd: _handleScaleEnd,
              child: CustomPaint(
                key: widget.canvasKey,
                painter: _cachedPainter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConstrainedVideoPreview() {
    final videoSize = widget.provider.videoEditorController?.video.value.size;
    if (videoSize == null) return const SizedBox.shrink();

    final cropRect = widget.provider.cropRect;
    final videoRotation = widget.provider.videoEditorController?.rotation ?? 0;
    Map<String, double> containerFitting;

    if (cropRect != null) {
      // ✅ FIXED: Use crop-adjusted fitting when crop is applied
      containerFitting =
          CanvasCoordinateManager.calculateCropAdjustedContainerFitting(
        videoWidth: videoSize.width,
        videoHeight: videoSize.height,
        containerWidth: widget.containerSize.width,
        containerHeight: widget.containerSize.height,
        cropRect: cropRect,
      );

      // ✅ NEW: If we also have rotation, we need to apply rotation to the crop-adjusted area
      if (videoRotation != 0) {
        print('=== Video Preview: Crop + Rotation Mode ===');

        // Get the base crop-adjusted area
        final basePreviewWidth = containerFitting['actualPreviewWidth']!;
        final basePreviewHeight = containerFitting['actualPreviewHeight']!;
        final baseGapLeft = containerFitting['gapLeft']!;
        final baseGapTop = containerFitting['gapTop']!;

        // Apply rotation to get the final rotated crop area
        final baseVideoArea = Rect.fromLTWH(
            baseGapLeft, baseGapTop, basePreviewWidth, basePreviewHeight);
        final rotatedVideoArea =
            _applyRotationToVideoArea(baseVideoArea, videoRotation);

        // Use the rotated area for preview
        containerFitting = {
          'actualPreviewWidth': rotatedVideoArea.width,
          'actualPreviewHeight': rotatedVideoArea.height,
          'gapLeft': rotatedVideoArea.left,
          'gapTop': rotatedVideoArea.top,
        };

        print('Base crop preview: ${basePreviewWidth} x ${basePreviewHeight}');
        print('Base crop gaps: left=${baseGapLeft}, top=${baseGapTop}');
        print(
            'Final rotated preview: ${rotatedVideoArea.width} x ${rotatedVideoArea.height}');
        print(
            'Final rotated gaps: left=${rotatedVideoArea.left}, top=${rotatedVideoArea.top}');
        print('=== End Video Preview: Crop + Rotation Mode ===');
      }
    } else {
      // ✅ FIXED: Check if video is rotated and use rotation-aware calculation
      if (videoRotation != 0) {
        print('=== Video Preview: Rotation Only Mode ===');
        // ✅ NEW: Get the rotated video area for proper preview calculation
        final rotatedVideoArea = _calculateRotatedVideoArea(videoRotation);
        containerFitting = {
          'actualPreviewWidth': rotatedVideoArea.width,
          'actualPreviewHeight': rotatedVideoArea.height,
          'gapLeft': rotatedVideoArea.left,
          'gapTop': rotatedVideoArea.top,
        };
        print('=== End Video Preview: Rotation Only Mode ===');
      } else {
        // ✅ Use normal fitting when no crop or rotation
        containerFitting = CanvasCoordinateManager.calculateContainerFitting(
          videoWidth: videoSize.width,
          videoHeight: videoSize.height,
          containerWidth: widget.containerSize.width,
          containerHeight: widget.containerSize.height,
        );
      }
    }

    final actualPreviewWidth = containerFitting['actualPreviewWidth']!;
    final actualPreviewHeight = containerFitting['actualPreviewHeight']!;
    final gapLeft = containerFitting['gapLeft']!;
    final gapTop = containerFitting['gapTop']!;

    return Positioned(
      left: gapLeft,
      top: gapTop,
      width: actualPreviewWidth,
      height: actualPreviewHeight,
      child: CropGridViewer.preview(
        key: ValueKey(widget.provider.textTracks.length),
        controller: widget.provider.videoEditorController!,
        overlayText: "", // Remove old text display
      ),
    );
  }

  // Track which text is being dragged
  TextTrackModel? _draggedTrack;

  // Local drag positions for smooth dragging (don't update provider until drag ends)
  final Map<String, Offset> _localDragPositions = {};

  // Note: _handleCanvasDrag removed - now handled by _handleScaleUpdate

  /// Apply smooth boundary constraints to prevent stuttering at edges
  Offset _applySmoothBoundaryConstraints(
    Offset newPosition,
    Offset currentPosition,
    Size textDimensions,
    double rotation,
  ) {
    final videoSize =
        widget.provider.videoEditorController?.video.value.size ?? Size.zero;
    final cropRect = widget.provider.cropRect;
    final videoRotation = widget.provider.videoEditorController?.rotation ?? 0;

    // Debug logging for landscape video issues
    final isLandscape = videoSize.width > videoSize.height;
    if (isLandscape) {
      print('=== Landscape Video Boundary Debug ===');
      print('Video size: ${videoSize.width} x ${videoSize.height}');
      print('Video rotation: ${videoRotation}°'); // ✅ NEW: Log rotation
      print(
          'Container size: ${widget.containerSize.width} x ${widget.containerSize.height}');
      print(
          'Text dimensions: ${textDimensions.width} x ${textDimensions.height}');
      print('New position: (${newPosition.dx}, ${newPosition.dy})');
      print('Current position: (${currentPosition.dx}, ${currentPosition.dy})');
      print('Crop rect: $cropRect');
    }

    // Declare boundary variables
    double minX, maxX, minY, maxY;

    if (cropRect == null) {
      // ✅ FIXED: No crop - use rotation-aware fitting
      if (videoRotation != 0) {
        print('=== Boundary: Using Rotated Video Area (No Crop) ===');
        // ✅ NEW: Get the rotated video area for proper boundary calculation
        final rotatedVideoArea = _calculateRotatedVideoArea(videoRotation);
        minX = rotatedVideoArea.left;
        maxX = rotatedVideoArea.right;
        minY = rotatedVideoArea.top;
        maxY = rotatedVideoArea.bottom;

        if (isLandscape) {
          print('Rotated video area: $rotatedVideoArea');
          print(
              'Rotated boundaries: minX=$minX, maxX=$maxX, minY=$minY, maxY=$maxY');
        }
        print('=== End Boundary: Rotated Video Area ===');
      } else {
        // No crop, no rotation - use normal fitting
        final containerFitting =
            CanvasCoordinateManager.calculateContainerFitting(
          videoWidth: videoSize.width,
          videoHeight: videoSize.height,
          containerWidth: widget.containerSize.width,
          containerHeight: widget.containerSize.height,
        );

        final actualPreviewWidth = containerFitting['actualPreviewWidth']!;
        final actualPreviewHeight = containerFitting['actualPreviewHeight']!;
        final gapLeft = containerFitting['gapLeft']!;
        final gapTop = containerFitting['gapTop']!;

        // No crop - use full video area boundaries
        minX = gapLeft;
        maxX = gapLeft + actualPreviewWidth;
        minY = gapTop;
        maxY = gapTop + actualPreviewHeight;

        if (isLandscape) {
          print(
              'No crop, no rotation - boundaries: minX=$minX, maxX=$maxX, minY=$minY, maxY=$maxY');
          print('Gaps: left=$gapLeft, top=$gapTop');
          print('Preview size: ${actualPreviewWidth} x ${actualPreviewHeight}');
        }
      }
    } else {
      // ✅ FIXED: CROP APPLIED - use rotation-aware crop calculation
      if (videoRotation != 0) {
        print('=== Boundary: Using Rotated Video Area (With Crop) ===');
        // ✅ NEW: Get the rotated video area for proper boundary calculation
        final rotatedVideoArea = _calculateRotatedVideoArea(videoRotation);
        minX = rotatedVideoArea.left;
        maxX = rotatedVideoArea.right;
        minY = rotatedVideoArea.top;
        maxY = rotatedVideoArea.bottom;

        if (isLandscape) {
          print('Rotated video area with crop: $rotatedVideoArea');
          print(
              'Rotated boundaries: minX=$minX, maxX=$maxX, minY=$minY, maxY=$maxY');
        }
        print('=== End Boundary: Rotated Video Area with Crop ===');
      } else {
        // Crop applied, no rotation - use existing crop logic
        // First, calculate how the original video is displayed (same as no-crop)
        final videoAspectRatio = videoSize.width / videoSize.height;
        final containerAspectRatio =
            widget.containerSize.width / widget.containerSize.height;

        double actualPreviewWidth,
            actualPreviewHeight,
            gapLeft = 0.0,
            gapTop = 0.0;
        if (videoAspectRatio > containerAspectRatio) {
          // Original video is wider - fit width, letterbox top/bottom
          actualPreviewWidth = widget.containerSize.width;
          actualPreviewHeight = widget.containerSize.width / videoAspectRatio;
          gapTop = (widget.containerSize.height - actualPreviewHeight) / 2.0;
        } else {
          // Original video is taller - fit height, letterbox left/right
          actualPreviewHeight = widget.containerSize.height;
          actualPreviewWidth = widget.containerSize.height * videoAspectRatio;
          gapLeft = (widget.containerSize.width - actualPreviewWidth) / 2.0;
        }

        // Now use ONLY the original video display area as the container for the cropped video
        // This means the cropped video is constrained to the same area where original video was shown
        final cropAspectRatio = cropRect.width / cropRect.height;
        final videoDisplayAspectRatio =
            actualPreviewWidth / actualPreviewHeight;

        double croppedPreviewWidth,
            croppedPreviewHeight,
            croppedGapLeft = 0.0,
            croppedGapTop = 0.0;
        if (cropAspectRatio > videoDisplayAspectRatio) {
          // Crop is wider than video display area: fit width, letterbox top/bottom within video area
          croppedPreviewWidth = actualPreviewWidth;
          croppedPreviewHeight = actualPreviewWidth / cropAspectRatio;
          croppedGapTop = (actualPreviewHeight - croppedPreviewHeight) / 2.0;
        } else {
          // Crop is taller than video display area: fit height, letterbox left/right within video area
          croppedPreviewHeight = actualPreviewHeight;
          croppedPreviewWidth = actualPreviewHeight * cropAspectRatio;
          croppedGapLeft = (actualPreviewWidth - croppedPreviewWidth) / 2.0;
        }

        // Final position within the original video display area (not the full container)
        final finalGapLeft = gapLeft + croppedGapLeft;
        final finalGapTop = gapTop + croppedGapTop;

        // Calculate cropped video area boundaries
        minX = finalGapLeft;
        maxX = finalGapLeft + croppedPreviewWidth;
        minY = finalGapTop;
        maxY = finalGapTop + croppedPreviewHeight;

        if (isLandscape) {
          print(
              'Crop applied, no rotation - boundaries: minX=$minX, maxX=$maxX, minY=$minY, maxY=$maxY');
          print('Original gaps: left=$gapLeft, top=$gapTop');
          print('Cropped gaps: left=$croppedGapLeft, top=$croppedGapTop');
          print('Final gaps: left=$finalGapLeft, top=$finalGapTop');
          print('Preview size: ${actualPreviewWidth} x ${actualPreviewHeight}');
          print(
              'Cropped preview size: ${croppedPreviewWidth} x ${croppedPreviewHeight}');
        }
      }
    }

    // ✅ FIXED: Calculate actual text dimensions for proper boundary checking
    // These variables must be available for all code paths
    final effectiveTextWidth = textDimensions.width;
    final effectiveTextHeight = textDimensions.height;

    if (isLandscape) {
      print(
          'Effective text size: ${effectiveTextWidth} x ${effectiveTextHeight}');
    }

    // Apply smooth boundary constraints
    double constrainedX = newPosition.dx;
    double constrainedY = newPosition.dy;

    // X-axis constraints
    if (newPosition.dx < minX) {
      // Prevent moving beyond left boundary
      constrainedX = currentPosition.dx; // Keep current position
      if (isLandscape)
        print(
            'X constraint: prevented left overflow, keeping current X: ${currentPosition.dx}');
    } else if (newPosition.dx + effectiveTextWidth > maxX) {
      // Prevent moving beyond right boundary
      constrainedX = currentPosition.dx; // Keep current position
      if (isLandscape)
        print(
            'X constraint: prevented right overflow, keeping current X: ${currentPosition.dx}');
    }

    // Y-axis constraints
    if (newPosition.dy < minY) {
      // Prevent moving beyond top boundary
      constrainedY = currentPosition.dy; // Keep current position
      if (isLandscape)
        print(
            'Y constraint: prevented top overflow, keeping current Y: ${currentPosition.dy}');
    } else if (newPosition.dy + effectiveTextHeight > maxY) {
      // Prevent moving beyond bottom boundary
      constrainedY = currentPosition.dy; // Keep current position
      if (isLandscape)
        print(
            'Y constraint: prevented bottom overflow, keeping current Y: ${currentPosition.dy}');
    }

    final result = Offset(constrainedX, constrainedY);

    if (isLandscape) {
      print('Final constrained position: (${result.dx}, ${result.dy})');
      print('=== End Landscape Video Boundary Debug ===');
    }

    return result;
  }

  /// Calculate actual text dimensions for boundary checking
  Size _calculateTextDimensions(TextTrackModel track) {
    final videoSize = widget.provider.videoEditorController?.video.value.size;
    if (videoSize == null) return Size(16.0, 16.0); // Default size

    // Debug logging for landscape video issues
    final isLandscape = videoSize.width > videoSize.height;
    if (isLandscape) {
      print('=== Landscape Video Text Dimensions Debug ===');
      print('Video size: ${videoSize.width} x ${videoSize.height}');
      print(
          'Container size: ${widget.containerSize.width} x ${widget.containerSize.height}');
      print('Track position: (${track.position.dx}, ${track.position.dy})');
      print('Track text: "${track.text}"');
      print('Base font size: ${track.fontSize}');
    }

    // Use CanvasFontManager for consistent font size calculation
    final fontSize = CanvasFontManager.calculateCanvasFontSize(
      baseFontSize: track.fontSize,
      targetSize: widget.containerSize,
      videoSize: videoSize,
      isPreview: true,
      videoRotation: widget.provider.videoEditorController?.rotation ?? 0,
      cropRect: widget.provider
          .cropRect, // ✅ ADDED: Pass crop rectangle for rotation-aware calculations
    );

    if (isLandscape) {
      print('Calculated font size: $fontSize');
    }

    final textStyle = TextStyle(
      fontSize: fontSize,
      fontFamily: track.fontFamily,
      height: 1.0,
    );

    // Calculate available space for text wrapping
    final availableSize = CanvasCoordinateManager.calculateAvailableSpace(
      textPosition: track.position,
      containerSize: widget.containerSize,
      videoSize: videoSize,
      cropRect: widget.provider.cropRect,
      boundaryBuffer: 10.0,
      rotation: widget.provider.videoEditorController?.rotation ?? 0,
    );

    if (isLandscape) {
      print(
          'Available space: ${availableSize.width} x ${availableSize.height}');
    }

    // Wrap text and calculate dimensions
    final wrappedLines = TextAutoWrapHelper.wrapTextToFit(
      track.text,
      availableSize.width,
      availableSize.height,
      textStyle,
    );

    if (isLandscape) {
      print('Wrapped lines: $wrappedLines');
    }

    final textHeight =
        TextAutoWrapHelper.calculateWrappedTextHeight(wrappedLines, textStyle);
    final textWidth = _calculateMaxLineWidth(wrappedLines, textStyle);

    final result = Size(textWidth, textHeight);

    if (isLandscape) {
      print('Final text dimensions: ${result.width} x ${result.height}');
      print('=== End Landscape Video Text Dimensions Debug ===');
    }

    return result;
  }

  // Note: _handleCanvasDragStart removed - now handled by _handleScaleStart

  // Note: _handleCanvasDragEnd removed - now handled by _handleScaleEnd

  // Rotation handling methods
  void _handleRotationStart(TextTrackModel track, Offset position) {
    print('=== Rotation Start Debug ===');
    print('Starting rotation for track: "${track.text}"');
    print('Current rotation: ${track.rotation}');
    print('Rotation center: (${position.dx}, ${position.dy})');

    setState(() {
      _rotatingTrack = track;
      _tempRotation = track.rotation;
      _cachedRotationCenter = position;
    });

    print(
        'Rotation state set: _rotatingTrack=${_rotatingTrack?.text}, _tempRotation=$_tempRotation');
    print('=== End Rotation Start Debug ===');
  }

  void _handleRotationUpdate(DragUpdateDetails details) {
    if (_rotatingTrack == null || _cachedRotationCenter == null) {
      print(
          'Rotation update skipped: _rotatingTrack=${_rotatingTrack?.text}, _cachedRotationCenter=$_cachedRotationCenter');
      return;
    }

    print('=== Rotation Update Debug ===');
    final touch = details.globalPosition;
    final delta = touch - _cachedRotationCenter!;
    final angleRad = math.atan2(delta.dy, delta.dx);
    final angleDeg = angleRad * 180 / math.pi;
    final normalized = angleDeg < 0 ? angleDeg + 360 : angleDeg;

    print('Touch position: (${touch.dx}, ${touch.dy})');
    print('Delta: (${delta.dx}, ${delta.dy})');
    print('Angle (radians): $angleRad');
    print('Angle (degrees): $angleDeg');
    print('Normalized angle: $normalized');
    print('=== End Rotation Update Debug ===');

    _throttledRotationUpdate(normalized);
  }

  void _handleRotationEnd(DragEndDetails details) {
    print('=== Rotation End Debug ===');
    if (_rotatingTrack == null) {
      print('Rotation end: No rotating track');
      return;
    }

    print('Ending rotation for track: "${_rotatingTrack!.text}"');
    print('Final temp rotation: $_tempRotation');
    print('Model rotation: ${_rotatingTrack!.rotation}');

    _throttleTimer?.cancel();
    final finalRotation = _tempRotation ?? _rotatingTrack!.rotation;
    final modelRotation = _rotatingTrack!.rotation;

    print('Final rotation: $finalRotation');
    print('Model rotation: $modelRotation');

    _animateRotationToFinal(finalRotation, modelRotation);
    _tempRotation = null;
    _cachedRotationCenter = null;
    _rotatingTrack = null;

    setState(() {});
    print('=== End Rotation End Debug ===');
  }

  void _throttledRotationUpdate(double angle) {
    print('=== Throttled Rotation Update Debug ===');
    print('Updating rotation to angle: $angle');
    print('Rotating track: "${_rotatingTrack?.text}"');

    _throttleTimer?.cancel();
    setState(() {
      _tempRotation = angle;
    });
    print('Temp rotation set to: $_tempRotation');

    _throttleTimer = Timer(const Duration(milliseconds: 16), () {
      print('Timer callback: Updating track rotation to: $angle');
      final updatedTrack = _rotatingTrack!.copyWith(rotation: angle);

      // Use safe update method
      if (!_safeUpdateTextTrack(_rotatingTrack!, updatedTrack)) {
        // Clean up the rotation state since the track is gone
        _rotatingTrack = null;
        _tempRotation = null;
        setState(() {});
      } else {
        print('Track rotation updated successfully');
      }
    });
    print('=== End Throttled Rotation Update Debug ===');
  }

  void _animateRotationToFinal(double from, double to) {
    _rotationAnim = Tween<double>(begin: from, end: to).animate(
      CurvedAnimation(parent: _rotationAnimController, curve: Curves.easeOut),
    );
    _rotationAnimController.forward(from: 0);
  }

  // Unified gesture handling methods
  void _handleScaleStart(ScaleStartDetails details) {
    print('=== Scale Start Debug ===');
    print(
        'Scale center: (${details.localFocalPoint.dx}, ${details.localFocalPoint.dy})');
    print('Focal point: (${details.focalPoint.dx}, ${details.focalPoint.dy})');

    // Debug: Show all text tracks and their positions
    _debugShowAllTextTracks();

    // Find which text track is at the scale center
    final touchedTrack = _hitTestText(details.localFocalPoint);
    if (touchedTrack != null) {
      print('Track found: "${touchedTrack.text}"');
      print('Current rotation: ${touchedTrack.rotation}');

      // Select the touched track
      final index = widget.provider.textTracks.indexOf(touchedTrack);

      // Validate that the track still exists in the provider's list
      if (index >= 0) {
        widget.provider.setTextTrackIndex(index);
        print('Track selected at index: $index');

        // Store initial state for both drag and rotation
        setState(() {
          _draggedTrack = touchedTrack;
          _scalingTrack = touchedTrack;
          _initialRotation = touchedTrack.rotation;
          _initialScale = 1.0;
          _scaleCenter = details.localFocalPoint;

          // Store initial position for drag calculations
          // Use adjusted position for rotated text to match visual position
          final effectivePosition = _calculateEffectivePosition(touchedTrack);
          Offset initialDragPosition;

          if (touchedTrack.rotation != 0) {
            // Get container fitting for proper boundary constraints
            final videoSize =
                widget.provider.videoEditorController?.video.value.size ??
                    Size.zero;
            Map<String, double> containerFitting;
            if (widget.provider.cropRect != null) {
              containerFitting =
                  CanvasCoordinateManager.calculateCropAdjustedContainerFitting(
                videoWidth: videoSize.width,
                videoHeight: videoSize.height,
                containerWidth: widget.containerSize.width,
                containerHeight: widget.containerSize.height,
                cropRect: widget.provider.cropRect!,
              );
            } else {
              containerFitting =
                  CanvasCoordinateManager.calculateContainerFitting(
                videoWidth: videoSize.width,
                videoHeight: videoSize.height,
                containerWidth: widget.containerSize.width,
                containerHeight: widget.containerSize.height,
              );
            }

            // Calculate adjusted position to keep rotated text within video preview boundaries
            initialDragPosition =
                TextRotationManager.calculateRotatedPositionWithVideoBounds(
              basePosition: effectivePosition,
              textWidth: _calculateTextDimensions(touchedTrack).width,
              textHeight: _calculateTextDimensions(touchedTrack).height,
              rotation: touchedTrack.rotation,
              containerSize: widget.containerSize,
              videoSize: videoSize,
              containerFitting: containerFitting,
              cropRect: widget.provider.cropRect,
            );

            print(
                'Initial drag position (adjusted for rotation): (${initialDragPosition.dx}, ${initialDragPosition.dy})');
          } else {
            initialDragPosition = effectivePosition;
            print(
                'Initial drag position (no rotation): (${initialDragPosition.dx}, ${initialDragPosition.dy})');
          }

          _localDragPositions[touchedTrack.id] = initialDragPosition;
        });
      } else {
        print(
            'Warning: Track no longer exists in provider list, cannot select it');
      }
    } else {
      print('No text track found at scale center');
    }
    print('=== End Scale Start Debug ===');
  }

  /// Debug method to show all text tracks and their positions
  void _debugShowAllTextTracks() {
    print('=== All Text Tracks Debug ===');
    print('Total text tracks: ${widget.provider.textTracks.length}');

    for (int i = 0; i < widget.provider.textTracks.length; i++) {
      final track = widget.provider.textTracks[i];
      print('Track $i: "${track.text}"');
      print('  Position: (${track.position.dx}, ${track.position.dy})');
      print('  Font size: ${track.fontSize}');
      print('  Visible: ${_isTrackVisible(track)}');

      if (_isTrackVisible(track)) {
        final bounds = _calculateApproximateBounds(track);
        print(
            '  Bounds: ${bounds.left}, ${bounds.top}, ${bounds.right}, ${bounds.bottom}');
        print('  Size: ${bounds.width} x ${bounds.height}');

        // Show effective position vs original position
        final effectivePos = _calculateEffectivePosition(track);
        print(
            '  Original position: (${track.position.dx}, ${track.position.dy})');
        print('  Effective position: (${effectivePos.dx}, ${effectivePos.dy})');
        print(
            '  Position difference: (${effectivePos.dx - track.position.dx}, ${effectivePos.dy - track.position.dy})');
      }
    }
    print('=== End All Text Tracks Debug ===');
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (_scalingTrack == null || _scaleCenter == null) {
      return;
    }

    print('=== Scale Update Debug ===');
    print('Scale: ${details.scale}');
    print('Rotation: ${details.rotation}');
    print('Focal point: (${details.focalPoint.dx}, ${details.focalPoint.dy})');
    print(
        'Focal point delta: (${details.focalPointDelta.dx}, ${details.focalPointDelta.dy})');

    // Calculate velocity for smoother movement
    final now = DateTime.now();
    if (_lastUpdateTime != null && _lastFocalPoint != null) {
      final timeDelta = now.difference(_lastUpdateTime!).inMilliseconds;
      if (timeDelta > 0) {
        final positionDelta = details.focalPoint - _lastFocalPoint!;
        _gestureVelocity = Offset(
          positionDelta.dx /
              timeDelta *
              16.67, // Convert to pixels per frame (60fps)
          positionDelta.dy / timeDelta * 16.67,
        );
      }
    }
    _lastFocalPoint = details.focalPoint;
    _lastUpdateTime = now;

    // Handle rotation if there's rotation input
    if (details.rotation != 0) {
      print('=== Handling Rotation ===');
      // Calculate new rotation based on two-finger gesture
      final newRotation =
          (_initialRotation ?? 0.0) + (details.rotation * 180 / math.pi);

      // Normalize rotation to 0-360 degree range
      final normalizedRotation = _normalizeRotation(newRotation);
      print('Raw rotation: $newRotation degrees');
      print('Normalized rotation: $normalizedRotation degrees');

      // Update local rotation state for immediate smooth visual feedback
      setState(() {
        _tempRotation = normalizedRotation;
      });

      // Throttle provider updates to avoid overwhelming the system (60fps)
      _throttleTimer?.cancel();
      _throttleTimer = Timer(const Duration(milliseconds: 16), () {
        if (_scalingTrack != null) {
          final updatedTrack =
              _scalingTrack!.copyWith(rotation: normalizedRotation);

          // Use safe update method
          if (!_safeUpdateTextTrack(_scalingTrack!, updatedTrack)) {
            // Clean up the scaling state since the track is gone
            _scalingTrack = null;
            _tempRotation = null;
            setState(() {});
          } else {
            print('Track rotation updated to: $normalizedRotation degrees');
          }
        }
      });
    }

    // Handle dragging if there's focal point movement
    if (details.focalPointDelta.distance > 0.1) {
      // Small threshold to avoid jitter
      print('=== Handling Drag ===');
      if (_draggedTrack != null) {
        final trackId = _draggedTrack!.id;
        final currentLocalPosition =
            _localDragPositions[trackId] ?? _draggedTrack!.position;

        // Calculate new position using focal point delta
        final newPosition = Offset(
          currentLocalPosition.dx + details.focalPointDelta.dx,
          currentLocalPosition.dy + details.focalPointDelta.dy,
        );

        // Get text dimensions for boundary calculation
        final textDimensions = _calculateTextDimensions(_draggedTrack!);

        // Apply smooth boundary constraints
        final validatedPosition = _applySmoothBoundaryConstraints(
          newPosition,
          currentLocalPosition,
          textDimensions,
          _draggedTrack!.rotation,
        );

        // Apply smooth easing for better visual feedback (0.8 = 80% of the way to target)
        final smoothedPosition =
            _applySmoothEasing(currentLocalPosition, validatedPosition, 0.8);

        // Store local position for smooth dragging
        _localDragPositions[trackId] = smoothedPosition;
        print(
            'Track dragged to: (${smoothedPosition.dx}, ${smoothedPosition.dy})');

        // Trigger immediate repaint for smooth visual feedback
        setState(() {});
      }
    }

    print('=== End Scale Update Debug ===');
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    if (_scalingTrack == null) {
      return;
    }

    print('=== Scale End Debug ===');
    print('Ending gesture for track: "${_scalingTrack!.text}"');
    print('Final rotation: $_tempRotation');

    // Commit final position if we were dragging
    if (_draggedTrack != null) {
      final trackId = _draggedTrack!.id;
      final finalPosition =
          _localDragPositions[trackId] ?? _draggedTrack!.position;

      // Update the provider with the final position
      final updatedTrack = _draggedTrack!.copyWith(position: finalPosition);

      // Use safe update method
      if (_safeUpdateTextTrack(_draggedTrack!, updatedTrack)) {
        print(
            'Final position committed: (${finalPosition.dx}, ${finalPosition.dy})');
      }

      // Clear local drag state
      _localDragPositions.remove(trackId);
      _draggedTrack = null;
    }

    // Clean up scale state
    _throttleTimer?.cancel();
    _scalingTrack = null;
    _initialRotation = null;
    _initialScale = null;
    _scaleCenter = null;
    _tempRotation = null;

    // Clean up velocity tracking
    _lastFocalPoint = null;
    _lastUpdateTime = null;
    _gestureVelocity = null;

    setState(() {});
    print('=== End Scale End Debug ===');
  }

  void _handleCanvasTap(TapDownDetails details) {
    // Find which text track was tapped
    final tappedTrack = _hitTestText(details.localPosition);
    if (tappedTrack != null) {
      // Select the tapped track
      final index = widget.provider.textTracks.indexOf(tappedTrack);
      widget.provider.setTextTrackIndex(index);
    }
  }

  TextTrackModel? _hitTestText(Offset position) {
    // Debug logging for all hit tests (not just landscape)
    final videoSize = widget.provider.videoEditorController?.video.value.size;
    final isLandscape = videoSize != null && videoSize.width > videoSize.height;

    print('=== Hit Test Debug ===');
    print('Hit test position: (${position.dx}, ${position.dy})');
    print('Video size: ${videoSize?.width} x ${videoSize?.height}');
    print(
        'Container size: ${widget.containerSize.width} x ${widget.containerSize.height}');
    print('Text tracks count: ${widget.provider.textTracks.length}');
    print('Is landscape: $isLandscape');

    // Simple hit testing - check if position is within any text track bounds
    for (final track in widget.provider.textTracks) {
      print('--- Checking track: "${track.text}" ---');
      print('Track position: (${track.position.dx}, ${track.position.dy})');
      print('Track font size: ${track.fontSize}');
      print('Track visible: ${_isTrackVisible(track)}');

      if (_isTrackVisible(track)) {
        // Calculate approximate bounds for hit testing
        final bounds = _calculateApproximateBounds(track);

        print(
            'Calculated bounds: ${bounds.left}, ${bounds.top}, ${bounds.right}, ${bounds.bottom}');
        print('Bounds width: ${bounds.width}, height: ${bounds.height}');
        print('Position contains: ${bounds.contains(position)}');

        // Add some tolerance for small text
        final tolerance =
            15.0; // Increased from 5.0 to 15.0 for easier selection of small text
        final expandedBounds = Rect.fromLTWH(
          bounds.left - tolerance,
          bounds.top - tolerance,
          bounds.width + (tolerance * 2),
          bounds.height + (tolerance * 2),
        );

        print(
            'Expanded bounds (with $tolerance tolerance): ${expandedBounds.left}, ${expandedBounds.top}, ${expandedBounds.right}, ${expandedBounds.bottom}');
        print('Expanded bounds contains: ${expandedBounds.contains(position)}');

        // Show distance from bounds center for debugging
        final boundsCenter = Offset(
            bounds.left + bounds.width / 2, bounds.top + bounds.height / 2);
        final distanceFromCenter = (position - boundsCenter).distance;
        print('Distance from bounds center: $distanceFromCenter');
        print('Touch position: (${position.dx}, ${position.dy})');
        print('Bounds center: (${boundsCenter.dx}, ${boundsCenter.dy})');

        if (bounds.contains(position) || expandedBounds.contains(position)) {
          print('Hit test successful for track: "${track.text}"');
          print('=== End Hit Test Debug ===');
          return track;
        }
      } else {
        print('Track not visible - skipping');
      }
    }

    print('Hit test failed - no tracks found at position');
    print('=== End Hit Test Debug ===');
    return null;
  }

  bool _isTrackVisible(TextTrackModel track) {
    final currentTime = widget.provider.currentVideoTime;
    final startTime = track.trimStartTime;
    final endTime = track.trimEndTime;
    return currentTime >= startTime && currentTime < endTime;
  }

  Rect _calculateApproximateBounds(TextTrackModel track) {
    final videoSize = widget.provider.videoEditorController?.video.value.size;
    if (videoSize == null) return Rect.zero;

    // Debug logging for all bounds calculations (not just landscape)
    final isLandscape = videoSize.width > videoSize.height;
    print('=== Bounds Calculation Debug ===');
    print('Track: "${track.text}"');
    print('Track position: (${track.position.dx}, ${track.position.dy})');
    print('Track font size: ${track.fontSize}');
    print('Video size: ${videoSize.width} x ${videoSize.height}');
    print(
        'Container size: ${widget.containerSize.width} x ${widget.containerSize.height}');
    print('Is landscape: $isLandscape');

    // Use CanvasFontManager and TextAutoWrapHelper for accurate calculations
    final fontSize = CanvasFontManager.calculateCanvasFontSize(
      baseFontSize: track.fontSize,
      targetSize: widget.containerSize,
      videoSize: videoSize,
      isPreview: true,
      videoRotation: widget.provider.videoEditorController?.rotation ?? 0,
      cropRect: widget.provider
          .cropRect, // ✅ ADDED: Pass crop rectangle for rotation-aware calculations
    );

    print('Base font size: ${track.fontSize}');
    print('Calculated font size: $fontSize');
    print('Font size ratio: ${fontSize / track.fontSize}');

    final textStyle = TextStyle(
      fontSize: fontSize,
      fontFamily: track.fontFamily,
      height: 1.0,
    );

    // Calculate available space for text wrapping
    final availableSize = CanvasCoordinateManager.calculateAvailableSpace(
      textPosition: track.position,
      containerSize: widget.containerSize,
      videoSize: videoSize,
      cropRect: widget.provider.cropRect,
      boundaryBuffer: 10.0,
      rotation: widget.provider.videoEditorController?.rotation ?? 0,
    );

    print('Available space: ${availableSize.width} x ${availableSize.height}');

    // Wrap text and calculate dimensions
    final wrappedLines = TextAutoWrapHelper.wrapTextToFit(
      track.text,
      availableSize.width,
      availableSize.height,
      textStyle,
    );

    print('Wrapped lines: $wrappedLines');

    final textHeight =
        TextAutoWrapHelper.calculateWrappedTextHeight(wrappedLines, textStyle);
    final textWidth = _calculateMaxLineWidth(wrappedLines, textStyle);

    print('Text dimensions: ${textWidth} x ${textHeight}');

    // Use the same coordinate calculation as the text painter
    final effectivePosition = _calculateEffectivePosition(track);
    print(
        'Effective position (same as painter): (${effectivePosition.dx}, ${effectivePosition.dy})');

    // For rotated text, use the same adjusted position calculation as the painter
    Offset adjustedPosition;
    if (track.rotation != 0) {
      // Get container fitting for proper boundary constraints
      Map<String, double> containerFitting;
      if (widget.provider.cropRect != null) {
        containerFitting =
            CanvasCoordinateManager.calculateCropAdjustedContainerFitting(
          videoWidth: videoSize.width,
          videoHeight: videoSize.height,
          containerWidth: widget.containerSize.width,
          containerHeight: widget.containerSize.height,
          cropRect: widget.provider.cropRect!,
        );
      } else {
        containerFitting = CanvasCoordinateManager.calculateContainerFitting(
          videoWidth: videoSize.width,
          videoHeight: videoSize.height,
          containerWidth: widget.containerSize.width,
          containerHeight: widget.containerSize.height,
        );
      }

      // Calculate adjusted position to keep rotated text within video preview boundaries
      adjustedPosition =
          TextRotationManager.calculateRotatedPositionWithVideoBounds(
        basePosition: effectivePosition,
        textWidth: textWidth,
        textHeight: textHeight,
        rotation: track.rotation,
        containerSize: widget.containerSize,
        videoSize: videoSize,
        containerFitting: containerFitting,
        cropRect: widget.provider.cropRect,
      );

      print(
          'Adjusted position for rotation: (${adjustedPosition.dx}, ${adjustedPosition.dy})');
    } else {
      adjustedPosition = effectivePosition;
    }

    final bounds = Rect.fromLTWH(
      adjustedPosition.dx,
      adjustedPosition.dy,
      textWidth,
      textHeight,
    );

    // Ensure minimum bounds size for very small text to remain selectable
    final minBoundsSize = 20.0; // Minimum 20x20 pixels for hit testing
    final adjustedBounds = Rect.fromLTWH(
      bounds.left,
      bounds.top,
      math.max(bounds.width, minBoundsSize),
      math.max(bounds.height, minBoundsSize),
    );

    print(
        'Original bounds: ${bounds.left}, ${bounds.top}, ${bounds.right}, ${bounds.bottom}');
    print(
        'Adjusted bounds (with min size): ${adjustedBounds.left}, ${adjustedBounds.top}, ${adjustedBounds.right}, ${adjustedBounds.bottom}');
    print('Bounds size: ${adjustedBounds.width} x ${adjustedBounds.height}');
    print('=== End Bounds Calculation Debug ===');

    return adjustedBounds;
  }

  /// Calculate maximum line width for text wrapping
  double _calculateMaxLineWidth(List<String> lines, TextStyle style) {
    double maxWidth = 0;
    for (final line in lines) {
      final textPainter = TextPainter(
        text: TextSpan(text: line, style: style),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      maxWidth = math.max(maxWidth, textPainter.width);
      textPainter.dispose();
    }
    return maxWidth;
  }

  /// Check if the touch is on a rotation handle
  bool _isRotationHandleTouched(Offset localPosition, TextTrackModel track) {
    print('=== Rotation Handle Detection Debug ===');
    print('Touch position: (${localPosition.dx}, ${localPosition.dy})');
    print('Track: "${track.text}"');
    print('Track position: (${track.position.dx}, ${track.position.dy})');

    final textDimensions = _calculateTextDimensions(track);
    print(
        'Text dimensions: ${textDimensions.width} x ${textDimensions.height}');

    final textStyle = TextStyle(
      fontSize:
          textDimensions.width / track.text.length, // Approximate font size
      fontFamily: track.fontFamily,
      height: 1.0,
    );
    print('Approximate font size: ${textDimensions.width / track.text.length}');

    final availableSize = CanvasCoordinateManager.calculateAvailableSpace(
      textPosition: track.position,
      containerSize: widget.containerSize,
      videoSize:
          widget.provider.videoEditorController?.video.value.size ?? Size.zero,
      cropRect: widget.provider.cropRect,
      boundaryBuffer: 10.0,
      rotation: widget.provider.videoEditorController?.rotation ?? 0,
    );
    print('Available space: ${availableSize.width} x ${availableSize.height}');

    final wrappedLines = TextAutoWrapHelper.wrapTextToFit(
      track.text,
      availableSize.width,
      availableSize.height,
      textStyle,
    );
    print('Wrapped lines: $wrappedLines');

    final textWidth = _calculateMaxLineWidth(wrappedLines, textStyle);
    final textHeight =
        TextAutoWrapHelper.calculateWrappedTextHeight(wrappedLines, textStyle);
    print('Calculated text dimensions: ${textWidth} x ${textHeight}');

    // Calculate rotation handle position (above the text)
    final handleSize =
        40.0; // Increased from 26.0 to 40.0 for easier touch detection
    final handleOffset =
        10.0; // Match the visual position in TextOverlayPainter

    // Use the same coordinate calculation as TextOverlayPainter
    final effectivePosition = _calculateEffectivePosition(track);
    print(
        'Effective position (same as visual): (${effectivePosition.dx}, ${effectivePosition.dy})');

    // Also check if we have a local drag position for this track
    final localDragPosition = _localDragPositions[track.id];
    if (localDragPosition != null) {
      print(
          'Using local drag position: (${localDragPosition.dx}, ${localDragPosition.dy})');
    }

    // Position the handle above the text center using effective position
    final handleCenter = Offset(
      effectivePosition.dx + textWidth / 2,
      effectivePosition.dy - handleOffset,
    );
    print('Handle center: (${handleCenter.dx}, ${handleCenter.dy})');
    print('Handle size: ${handleSize} x ${handleSize}');
    print('Handle offset from text: $handleOffset');

    // Check if touch is within the rotation handle area
    final handleRect = Rect.fromCenter(
      center: handleCenter,
      width: handleSize,
      height: handleSize,
    );
    print(
        'Handle rectangle: ${handleRect.left}, ${handleRect.top}, ${handleRect.right}, ${handleRect.bottom}');

    final isTouched = handleRect.contains(localPosition);
    print('Touch position contains in handle: $isTouched');

    // Additional debug: show distance from handle center
    final distance = (localPosition - handleCenter).distance;
    print(
        'Distance from handle center: $distance (max allowed: ${handleSize / 2})');

    // Fallback: proximity-based detection if exact hit test fails
    final proximityThreshold = handleSize / 2 + 10.0; // Allow 10px tolerance
    final isNearHandle = distance <= proximityThreshold;
    print(
        'Proximity detection: $isNearHandle (threshold: $proximityThreshold)');

    print('=== End Rotation Handle Detection Debug ===');

    return isTouched || isNearHandle;
  }

  /// Calculate effective position using the same logic as TextOverlayPainter
  Offset _calculateEffectivePosition(TextTrackModel track) {
    final videoSize = widget.provider.videoEditorController?.video.value.size;
    if (videoSize == null) return track.position;

    // Check if we have a local drag position for this track
    final localPosition = _localDragPositions[track.id];
    if (localPosition != null) {
      // Use local drag position for smooth dragging
      return localPosition;
    }

    // Use the same coordinate calculation as TextOverlayPainter._calculatePreviewPosition
    final cropRect = widget.provider.cropRect;
    Map<String, double> containerFitting;

    if (cropRect != null) {
      containerFitting =
          CanvasCoordinateManager.calculateCropAdjustedContainerFitting(
        videoWidth: videoSize.width,
        videoHeight: videoSize.height,
        containerWidth: widget.containerSize.width,
        containerHeight: widget.containerSize.height,
        cropRect: cropRect,
      );
    } else {
      containerFitting = CanvasCoordinateManager.calculateContainerFitting(
        videoWidth: videoSize.width,
        videoHeight: videoSize.height,
        containerWidth: widget.containerSize.width,
        containerHeight: widget.containerSize.height,
      );
    }

    final actualPreviewWidth = containerFitting['actualPreviewWidth']!;
    final actualPreviewHeight = containerFitting['actualPreviewHeight']!;
    final gapLeft = containerFitting['gapLeft']!;
    final gapTop = containerFitting['gapTop']!;

    // Map from preview coordinates to video coordinates
    final videoX =
        (track.position.dx - gapLeft) * (videoSize.width / actualPreviewWidth);
    final videoY =
        (track.position.dy - gapTop) * (videoSize.height / actualPreviewHeight);

    // Map back to preview coordinates
    final previewX = (videoX * actualPreviewWidth / videoSize.width) + gapLeft;
    final previewY = (videoY * actualPreviewHeight / videoSize.height) + gapTop;

    return Offset(previewX, previewY);
  }

  /// ✅ NEW: Store original text positions before any video rotation is applied
  void _storeOriginalTextPositionsForRotation() {
    print('=== Storing Original Text Positions for Rotation ===');
    _originalTextPositionsForRotation.clear();

    for (final track in widget.provider.textTracks) {
      _originalTextPositionsForRotation[track.id] = track.position;
      print(
          'Stored position for "${track.text}": (${track.position.dx}, ${track.position.dy})');
    }

    print(
        'Stored ${_originalTextPositionsForRotation.length} text positions for rotation');
    print('=== End Storing Original Text Positions for Rotation ===');
  }

  /// ✅ NEW: Update stored text positions to use current positions as the new reference
  void _updateStoredTextPositionsForRotation() {
    print('=== Updating Stored Text Positions for Rotation ===');

    for (final track in widget.provider.textTracks) {
      final oldPosition = _originalTextPositionsForRotation[track.id];
      final newPosition = track.position;

      if (oldPosition != null) {
        print('Updating stored position for "${track.text}":');
        print('  Old stored: (${oldPosition.dx}, ${oldPosition.dy})');
        print('  New current: (${newPosition.dx}, ${newPosition.dy})');
      } else {
        print(
            'Adding new stored position for "${track.text}": (${newPosition.dx}, ${newPosition.dy})');
      }

      _originalTextPositionsForRotation[track.id] = newPosition;
    }

    print(
        'Updated ${_originalTextPositionsForRotation.length} text positions for rotation');
    print('=== End Updating Stored Text Positions for Rotation ===');
  }

  /// ✅ NEW: Remap text positions to fit within the new rotated video area
  void _remapTextPositionsForVideoRotation(int newRotation) {
    print('=== Remapping Text Positions for Video Rotation ===');
    print('New rotation: ${newRotation}°');

    final videoSize = widget.provider.videoEditorController?.video.value.size;
    if (videoSize == null) {
      print('Error: Video size not available');
      return;
    }

    // Calculate the new rotated video area boundaries
    final rotatedVideoArea = _calculateRotatedVideoArea(newRotation);
    print('Rotated video area: $rotatedVideoArea');

    for (int i = 0; i < widget.provider.textTracks.length; i++) {
      final track = widget.provider.textTracks[i];
      final originalPosition = _originalTextPositionsForRotation[track.id];

      if (originalPosition != null) {
        print('--- Remapping track: "${track.text}" ---');
        print(
            'Original position: (${originalPosition.dx}, ${originalPosition.dy})');

        // Calculate proportional position within the rotated area
        final remappedPosition = _calculateProportionalPositionForVideoRotation(
          originalPosition: originalPosition,
          oldVideoArea: _getFullVideoArea(),
          newVideoArea: rotatedVideoArea,
          oldRotation: _lastVideoRotation ?? 0,
          newRotation: newRotation,
        );

        print(
            'Proportional position: (${remappedPosition.dx}, ${remappedPosition.dy})');

        // ✅ FIXED: Add try-catch to prevent crashes during position remapping
        try {
          // Check if the proportional position is within bounds
          if (_isPositionWithinBounds(
              remappedPosition, rotatedVideoArea, track)) {
            print('Proportional position is within bounds - using it');
            _updateTextTrackPosition(i, remappedPosition);
          } else {
            print('Proportional position is outside bounds - using fallback');
            final fallbackPosition =
                _calculateTopLeftFallbackPosition(rotatedVideoArea, track);
            print(
                'Fallback position: (${fallbackPosition.dx}, ${fallbackPosition.dy})');
            _updateTextTrackPosition(i, fallbackPosition);
          }
        } catch (e) {
          print(
              'ERROR: Failed to remap position for track "${track.text}": $e');
          print('Using safe fallback position');
          // Use a safe fallback position
          final safePosition = Offset(10.0, 10.0);
          _updateTextTrackPosition(i, safePosition);
        }
      }
    }

    _hasRemappedTextPositionsForRotation = true;
    print('=== End Remapping Text Positions for Video Rotation ===');
  }

  /// ✅ NEW: Calculate the rotated video area boundaries
  Rect _calculateRotatedVideoArea(int rotation) {
    final videoSize = widget.provider.videoEditorController?.video.value.size;
    if (videoSize == null) return Rect.zero;

    print('=== Rotated Video Area Calculation ===');
    print('Video size: ${videoSize.width} x ${videoSize.height}');
    print('Rotation: ${rotation}°');
    print(
        'Container size: ${widget.containerSize.width} x ${widget.containerSize.height}');
    print('Crop rect: ${widget.provider.cropRect}');

    // ✅ FIXED: Get the CURRENT video display area (which might be crop-adjusted)
    // instead of trying to fit rotated video into the full container
    final currentVideoArea = _getCurrentVideoDisplayArea();
    print(
        'Current video display area: ${currentVideoArea.left}, ${currentVideoArea.top}, ${currentVideoArea.right}, ${currentVideoArea.bottom}');
    print(
        'Current video area dimensions: ${currentVideoArea.width} x ${currentVideoArea.height}');

    // ✅ FIXED: Apply rotation to the CURRENT video display area
    final rotatedVideoArea =
        _applyRotationToVideoArea(currentVideoArea, rotation);
    print(
        'Rotated video area: ${rotatedVideoArea.left}, ${rotatedVideoArea.top}, ${rotatedVideoArea.right}, ${rotatedVideoArea.bottom}');
    print(
        'Rotated video area dimensions: ${rotatedVideoArea.width} x ${rotatedVideoArea.height}');

    // ✅ ADDED: Validate rotated video area before returning
    if (rotatedVideoArea.width <= 0 || rotatedVideoArea.height <= 0) {
      print('ERROR: Invalid rotated video area dimensions detected!');
      print('Falling back to current video area');
      return currentVideoArea;
    }

    // ✅ NEW: Verify the rotated area fits within the container
    final containerArea = Rect.fromLTWH(
        0, 0, widget.containerSize.width, widget.containerSize.height);
    print(
        'Container area: ${containerArea.left}, ${containerArea.top}, ${containerArea.right}, ${containerArea.bottom}');
    print(
        'Container dimensions: ${containerArea.width} x ${containerArea.height}');

    // ✅ NEW: Check if rotated video area fits within container bounds
    final rotatedAreaFitsInContainer =
        rotatedVideoArea.left >= containerArea.left &&
            rotatedVideoArea.top >= containerArea.top &&
            rotatedVideoArea.right <= containerArea.right &&
            rotatedVideoArea.bottom <= containerArea.bottom;
    print(
        'Rotated video area fits within container: $rotatedAreaFitsInContainer');

    // ✅ NEW: Calculate the effective gaps for text boundaries
    // These are the gaps that the rotated video actually has within the container
    final effectiveGapLeft = rotatedVideoArea.left;
    final effectiveGapTop = rotatedVideoArea.top;
    final effectiveGapRight = containerArea.right - rotatedVideoArea.right;
    final effectiveGapBottom = containerArea.bottom - rotatedVideoArea.bottom;

    print('=== Effective Gaps for Text Boundaries ===');
    print('Effective gap left: $effectiveGapLeft');
    print('Effective gap top: $effectiveGapTop');
    print('Effective gap right: $effectiveGapRight');
    print('Effective gap bottom: $effectiveGapBottom');
    print('=== End Effective Gaps for Text Boundaries ===');

    print('=== End Rotated Video Area Calculation ===');

    return rotatedVideoArea;
  }

  /// ✅ NEW: Get the current video display area (considering crop and other operations)
  Rect _getCurrentVideoDisplayArea() {
    // ✅ FIXED: Use the new helper method for consistency
    return _calculateEffectiveVideoArea();
  }

  /// ✅ NEW: Apply rotation to the current video display area
  Rect _applyRotationToVideoArea(Rect currentVideoArea, int rotation) {
    print('=== Applying Rotation to Video Area ===');
    print(
        'Current video area: ${currentVideoArea.left}, ${currentVideoArea.top}, ${currentVideoArea.width} x ${currentVideoArea.height}');
    print('Rotation: ${rotation}°');

    // For rotation, we need to consider how the rotated video fits within the current display area
    // This is similar to how crop works - we're constraining the rotated video to the current area

    final videoSize = widget.provider.videoEditorController?.video.value.size;
    if (videoSize == null) return currentVideoArea;

    // ✅ FIXED: Check if we have a crop applied first
    final cropRect = widget.provider.cropRect;
    final hasCrop = cropRect != null;

    if (hasCrop) {
      print('=== Crop + Rotation Mode ===');
      print(
          'Crop rect: ${cropRect!.left}, ${cropRect.top}, ${cropRect.right}, ${cropRect.bottom}');
      print('Crop dimensions: ${cropRect.width} x ${cropRect.height}');

      // ✅ NEW: When crop is applied first, we need to rotate the CROPPED video area
      // The rotated video should maintain the same crop boundaries but with rotated dimensions

      // Calculate the effective video dimensions after rotation
      final isRotated = rotation == 90 || rotation == 270;
      double effectiveCropWidth, effectiveCropHeight;

      if (isRotated) {
        // Swap dimensions for rotated video (90° and 270°)
        effectiveCropWidth = cropRect.height;
        effectiveCropHeight = cropRect.width;
        print(
            'Swapped crop dimensions for rotation: ${effectiveCropWidth} x ${effectiveCropHeight}');
      } else {
        // Keep original dimensions for 0° and 180°
        effectiveCropWidth = cropRect.width;
        effectiveCropHeight = cropRect.height;
        print(
            'Kept original crop dimensions: ${effectiveCropWidth} x ${effectiveCropHeight}');
      }

      // ✅ NEW: Fit the rotated CROPPED video within the current video display area
      // This ensures we respect the original crop constraints
      final currentAspectRatio =
          currentVideoArea.width / currentVideoArea.height;
      final rotatedCropAspectRatio = effectiveCropWidth / effectiveCropHeight;

      double rotatedWidth, rotatedHeight, rotatedLeft, rotatedTop;

      if (rotatedCropAspectRatio > currentAspectRatio) {
        // Rotated crop is wider - fit width, center height within current area
        rotatedWidth = currentVideoArea.width;
        rotatedHeight = currentVideoArea.width / rotatedCropAspectRatio;
        rotatedTop = currentVideoArea.top +
            (currentVideoArea.height - rotatedHeight) / 2.0;
        rotatedLeft = currentVideoArea.left;
      } else {
        // Rotated crop is taller - fit height, center width within current area
        rotatedHeight = currentVideoArea.height;
        rotatedWidth = currentVideoArea.height * rotatedCropAspectRatio;
        rotatedLeft = currentVideoArea.left +
            (currentVideoArea.width - rotatedWidth) / 2.0;
        rotatedTop = currentVideoArea.top;
      }

      print('=== Rotated Crop Fitting Details ===');
      print(
          'Current area: ${currentVideoArea.width} x ${currentVideoArea.height}');
      print('Original crop: ${cropRect.width} x ${cropRect.height}');
      print(
          'Effective rotated crop: ${effectiveCropWidth} x ${effectiveCropHeight}');
      print('Rotated crop aspect ratio: $rotatedCropAspectRatio');
      print('Current area aspect ratio: $currentAspectRatio');
      print('Fitted rotated size: ${rotatedWidth} x ${rotatedHeight}');
      print('Fitted rotated position: left=${rotatedLeft}, top=${rotatedTop}');
      print('=== End Rotated Crop Fitting Details ===');

      // ✅ ADDED: Validate calculated dimensions before returning
      if (rotatedWidth <= 0 || rotatedHeight <= 0) {
        print('ERROR: Invalid calculated dimensions detected!');
        print('Falling back to current video area');
        return currentVideoArea;
      }

      // ✅ ADDED: Validate calculated position bounds
      if (rotatedLeft < 0 || rotatedTop < 0) {
        print('ERROR: Invalid calculated position detected!');
        print('Falling back to current video area');
        return currentVideoArea;
      }

      print('=== End Crop + Rotation Mode ===');
      return Rect.fromLTWH(
          rotatedLeft, rotatedTop, rotatedWidth, rotatedHeight);
    } else {
      // ✅ FIXED: No crop - use original rotation logic
      print('=== No Crop + Rotation Mode ===');

      // Calculate the effective video dimensions after rotation
      final isRotated = rotation == 90 || rotation == 270;
      double effectiveVideoWidth, effectiveVideoHeight;

      if (isRotated) {
        // Swap dimensions for rotated video (90° and 270°)
        effectiveVideoWidth = videoSize.height;
        effectiveVideoHeight = videoSize.width;
        print(
            'Swapped dimensions for rotation: ${effectiveVideoWidth} x ${effectiveVideoHeight}');
      } else {
        // Keep original dimensions for 0° and 180°
        effectiveVideoWidth = videoSize.width;
        effectiveVideoHeight = videoSize.height;
        print(
            'Kept original dimensions: ${effectiveVideoWidth} x ${effectiveVideoHeight}');
      }

      // ✅ FIXED: Fit the rotated video within the CURRENT video display area
      // This ensures we respect any existing crop or other constraints
      final currentAspectRatio =
          currentVideoArea.width / currentVideoArea.height;
      final rotatedAspectRatio = effectiveVideoWidth / effectiveVideoHeight;

      double rotatedWidth, rotatedHeight, rotatedLeft, rotatedTop;

      if (rotatedAspectRatio > currentAspectRatio) {
        // Rotated video is wider - fit width, center height within current area
        rotatedWidth = currentVideoArea.width;
        rotatedHeight = currentVideoArea.width / rotatedAspectRatio;
        rotatedTop = currentVideoArea.top +
            (currentVideoArea.height - rotatedHeight) / 2.0;
        rotatedLeft = currentVideoArea.left;
      } else {
        // Rotated video is taller - fit height, center width within current area
        rotatedHeight = currentVideoArea.height;
        rotatedWidth = currentVideoArea.height * rotatedAspectRatio;
        rotatedLeft = currentVideoArea.left +
            (currentVideoArea.width - rotatedWidth) / 2.0;
        rotatedTop = currentVideoArea.top;
      }

      print('=== Rotated Video Fitting Details ===');
      print(
          'Current area: ${currentVideoArea.width} x ${currentVideoArea.height}');
      print(
          'Rotated video dimensions: ${effectiveVideoWidth} x ${effectiveVideoHeight}');
      print('Rotated video aspect ratio: $rotatedAspectRatio');
      print('Current area aspect ratio: $currentAspectRatio');
      print('Fitted rotated size: ${rotatedWidth} x ${rotatedHeight}');
      print('Fitted rotated position: left=${rotatedLeft}, top=${rotatedTop}');

      // ✅ NEW: Calculate the NEW gaps that result from fitting rotated video
      final newGapLeft = rotatedLeft - currentVideoArea.left;
      final newGapTop = rotatedTop - currentVideoArea.top;
      final newGapRight = (currentVideoArea.left + currentVideoArea.width) -
          (rotatedLeft + rotatedWidth);
      final newGapBottom = (currentVideoArea.top + currentVideoArea.height) -
          (rotatedTop + rotatedHeight);

      print('New gaps from rotation fitting:');
      print('  Left: $newGapLeft (original: ${currentVideoArea.left})');
      print('  Top: $newGapTop (original: ${currentVideoArea.top})');
      print('  Right: $newGapRight');
      print('  Bottom: $newGapBottom');
      print('=== End Rotated Video Fitting Details ===');

      // ✅ ADDED: Validate calculated dimensions before returning
      if (rotatedWidth <= 0 || rotatedHeight <= 0) {
        print('ERROR: Invalid calculated dimensions detected!');
        print('Falling back to current video area');
        return currentVideoArea;
      }

      // ✅ ADDED: Validate calculated position bounds
      if (rotatedLeft < 0 || rotatedTop < 0) {
        print('ERROR: Invalid calculated position detected!');
        print('Falling back to current video area');
        return currentVideoArea;
      }

      print('=== End No Crop + Rotation Mode ===');
      return Rect.fromLTWH(
          rotatedLeft, rotatedTop, rotatedWidth, rotatedHeight);
    }
  }

  /// ✅ NEW: Calculate proportional position for video rotation
  Offset _calculateProportionalPositionForVideoRotation({
    required Offset originalPosition,
    required Rect oldVideoArea,
    required Rect newVideoArea,
    required int oldRotation,
    required int newRotation,
  }) {
    print('=== Video Rotation Proportional Position Calculation ===');
    print(
        'Original position: (${originalPosition.dx}, ${originalPosition.dy})');
    print(
        'Old video area: ${oldVideoArea.left}, ${oldVideoArea.top}, ${oldVideoArea.right}, ${oldVideoArea.bottom}');
    print(
        'New video area: ${newVideoArea.left}, ${newVideoArea.top}, ${newVideoArea.right}, ${newVideoArea.bottom}');
    print('Old rotation: ${oldRotation}°, New rotation: ${newRotation}°');

    // Convert original position to percentage within the old video area
    final percentX =
        (originalPosition.dx - oldVideoArea.left) / oldVideoArea.width;
    final percentY =
        (originalPosition.dy - oldVideoArea.top) / oldVideoArea.height;

    print(
        'Position percentages: X=${(percentX * 100).toStringAsFixed(2)}%, Y=${(percentY * 100).toStringAsFixed(2)}%');

    // Apply the same percentage to the new rotated video area
    final newX = newVideoArea.left + (percentX * newVideoArea.width);
    final newY = newVideoArea.top + (percentY * newVideoArea.height);

    print(
        'Calculated new position: (${newX.toStringAsFixed(2)}, ${newY.toStringAsFixed(2)})');

    // ✅ NEW: Verify the new position is within the new video area
    final newPosition = Offset(newX, newY);
    final positionInNewArea = newVideoArea.contains(newPosition);
    print('New position within new video area: $positionInNewArea');

    // ✅ NEW: Calculate distance from video area center for debugging
    final oldCenter = Offset(oldVideoArea.left + oldVideoArea.width / 2,
        oldVideoArea.top + oldVideoArea.height / 2);
    final newCenter = Offset(newVideoArea.left + newVideoArea.width / 2,
        newVideoArea.top + newVideoArea.height / 2);
    final oldDistanceFromCenter = (originalPosition - oldCenter).distance;
    final newDistanceFromCenter = (newPosition - newCenter).distance;
    print(
        'Old distance from center: ${oldDistanceFromCenter.toStringAsFixed(2)}');
    print(
        'New distance from center: ${newDistanceFromCenter.toStringAsFixed(2)}');

    print('=== End Video Rotation Proportional Position Calculation ===');

    return newPosition;
  }

  /// ✅ NEW: Calculate the effective video area considering both crop and rotation
  Rect _calculateEffectiveVideoArea() {
    final videoSize = widget.provider.videoEditorController?.video.value.size;
    if (videoSize == null) return Rect.zero;

    final cropRect = widget.provider.cropRect;
    final videoRotation = widget.provider.videoEditorController?.rotation ?? 0;

    print('=== Effective Video Area Calculation ===');
    print('Crop rect: $cropRect');
    print('Video rotation: ${videoRotation}°');

    if (cropRect != null && videoRotation != 0) {
      // ✅ NEW: Both crop and rotation applied
      print('=== Crop + Rotation Mode ===');

      // First, calculate the base crop-adjusted area
      Map<String, double> containerFitting =
          CanvasCoordinateManager.calculateCropAdjustedContainerFitting(
        videoWidth: videoSize.width,
        videoHeight: videoSize.height,
        containerWidth: widget.containerSize.width,
        containerHeight: widget.containerSize.height,
        cropRect: cropRect,
      );

      final basePreviewWidth = containerFitting['actualPreviewWidth']!;
      final basePreviewHeight = containerFitting['actualPreviewHeight']!;
      final baseGapLeft = containerFitting['gapLeft']!;
      final baseGapTop = containerFitting['gapTop']!;

      print('Base crop area: ${basePreviewWidth} x ${basePreviewHeight}');
      print('Base gaps: left=${baseGapLeft}, top=${baseGapTop}');

      // Now apply rotation to this base area
      final baseVideoArea = Rect.fromLTWH(
          baseGapLeft, baseGapTop, basePreviewWidth, basePreviewHeight);
      final rotatedVideoArea =
          _applyRotationToVideoArea(baseVideoArea, videoRotation);

      print(
          'Final rotated crop area: ${rotatedVideoArea.width} x ${rotatedVideoArea.height}');
      print(
          'Final rotated gaps: left=${rotatedVideoArea.left}, top=${rotatedVideoArea.top}');
      print('=== End Crop + Rotation Mode ===');

      return rotatedVideoArea;
    } else if (cropRect != null) {
      // ✅ Crop only
      print('=== Crop Only Mode ===');
      final containerFitting =
          CanvasCoordinateManager.calculateCropAdjustedContainerFitting(
        videoWidth: videoSize.width,
        videoHeight: videoSize.height,
        containerWidth: widget.containerSize.width,
        containerHeight: widget.containerSize.height,
        cropRect: cropRect,
      );

      final actualPreviewWidth = containerFitting['actualPreviewWidth']!;
      final actualPreviewHeight = containerFitting['actualPreviewHeight']!;
      final gapLeft = containerFitting['gapLeft']!;
      final gapTop = containerFitting['gapTop']!;

      print('Crop preview: ${actualPreviewWidth} x ${actualPreviewHeight}');
      print('Crop gaps: left=${gapLeft}, top=${gapTop}');
      print('=== End Crop Only Mode ===');

      return Rect.fromLTWH(
          gapLeft, gapTop, actualPreviewWidth, actualPreviewHeight);
    } else if (videoRotation != 0) {
      // ✅ Rotation only
      print('=== Rotation Only Mode ===');
      final containerFitting =
          CanvasCoordinateManager.calculateContainerFitting(
        videoWidth: videoSize.width,
        videoHeight: videoSize.height,
        containerWidth: widget.containerSize.width,
        containerHeight: widget.containerSize.height,
      );

      final actualPreviewWidth = containerFitting['actualPreviewWidth']!;
      final actualPreviewHeight = containerFitting['actualPreviewHeight']!;
      final gapLeft = containerFitting['gapLeft']!;
      final gapTop = containerFitting['gapTop']!;

      // Apply rotation to the base area
      final baseVideoArea = Rect.fromLTWH(
          gapLeft, gapTop, actualPreviewWidth, actualPreviewHeight);
      final rotatedVideoArea =
          _applyRotationToVideoArea(baseVideoArea, videoRotation);

      print('Base preview: ${actualPreviewWidth} x ${actualPreviewHeight}');
      print('Base gaps: left=${gapLeft}, top=${gapTop}');
      print(
          'Final rotated area: ${rotatedVideoArea.width} x ${rotatedVideoArea.height}');
      print(
          'Final rotated gaps: left=${rotatedVideoArea.left}, top=${rotatedVideoArea.top}');
      print('=== End Rotation Only Mode ===');

      return rotatedVideoArea;
    } else {
      // ✅ No crop, no rotation
      print('=== No Crop, No Rotation Mode ===');
      final containerFitting =
          CanvasCoordinateManager.calculateContainerFitting(
        videoWidth: videoSize.width,
        videoHeight: videoSize.height,
        containerWidth: widget.containerSize.width,
        containerHeight: widget.containerSize.height,
      );

      final actualPreviewWidth = containerFitting['actualPreviewWidth']!;
      final actualPreviewHeight = containerFitting['actualPreviewHeight']!;
      final gapLeft = containerFitting['gapLeft']!;
      final gapTop = containerFitting['gapTop']!;

      print('Normal preview: ${actualPreviewWidth} x ${actualPreviewHeight}');
      print('Normal gaps: left=${gapLeft}, top=${gapTop}');
      print('=== End No Crop, No Rotation Mode ===');

      return Rect.fromLTWH(
          gapLeft, gapTop, actualPreviewWidth, actualPreviewHeight);
    }
  }
}
