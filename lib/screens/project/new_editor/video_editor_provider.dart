import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:ai_video_creator_editor/controllers/video_controller.dart';
import 'package:ai_video_creator_editor/screens/project/editor_controller.dart';
import 'package:ai_video_creator_editor/screens/project/models/audio_track_model.dart';
import 'package:ai_video_creator_editor/screens/project/models/text_track_model.dart';
import 'package:ai_video_creator_editor/screens/project/models/video_track_model.dart';
import 'package:ai_video_creator_editor/enums/track_type.dart';
import 'package:ai_video_creator_editor/enums/edit_operation.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/audio_trimmer.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/text_overlay_manager.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/transition_picker.dart';
import 'package:ai_video_creator_editor/utils/snack_bar_utils.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../utils/functions.dart';
import 'caption_editor.dart';
import 'frame_extractor.dart';
import 'package:ai_video_creator_editor/screens/project/models/overlay_video_track_model.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/master_timeline_controller.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/video_editor_page_updated.dart';

class VideoEditorProvider with ChangeNotifier {
  // Controllers
  VideoEditorController? _videoEditorController;
  MasterTimelineController _masterTimelineController =
      MasterTimelineController();
  LinkedScrollControllerGroup _linkedScrollControllerGroup =
      LinkedScrollControllerGroup();
  ScrollController? _videoScrollController;
  ScrollController? _audioScrollController;
  ScrollController? _textScrollController;
  ScrollController? _bottomScrollController;
  TextEditingController _textEditingController = TextEditingController();
  AudioPlayer? _audioController;

  // Basic properties
  bool _isInitializingVideo = false;
  String? _selectedAudio;
  List<String> _assets = [];
  List<TextOverlay> _textOverlays = [];
  String _currentFilter = 'none';
  String? _currentVideoPath;
  CanvasRatio _selectedCanvasRatio = CanvasRatio.RATIO_9_16;
  CanvasRatio?
      _previousCanvasRatio; // Track previous ratio for position recalculation
  EditMode _editMode = EditMode.none;
  Duration? _audioDuration;
  List<VideoCaption> _captions = [];
  List<VideoTrackModel> _videoTracks = [];
  List<AudioTrackModel> _audioTracks = [];
  List<TextTrackModel> _textTracks = [];
  int _selectedVideoTrackIndex = -1;
  int _selectedAudioTrackIndex = -1;
  int _selectedTextTrackIndex = -1;
  int _processingVideoTrackIndex =
      -1; // Track which video is processing stretch

  // Active stretch tracking (for timeline width adjustment during drag)
  int _activeStretchTrackIndex = -1;
  double _activeStretchVisualDuration = 0.0;

  // Trim and crop properties
  double _trimStart = 0.0;
  double _trimEnd = 0.0;
  double _audioTrimStart = 0.0;
  double _audioTrimEnd = 0.0;
  Rect? _cropRect;

  // Video manipulation properties
  int _rotation = 0;
  // Note: Global transition removed - now stored per-asset in VideoTrackModel
  double _playbackSpeed = 1.0;
  double _videoVolume = 1.0;
  double _audioVolume = 1.0;

  // UI state properties
  bool loading = false;
  bool _isPlaying = false;
  bool _isExtractingFrames = false;
  List<String> _framePaths = [];
  List<double> _waveformData = [];
  bool _textFieldVisibility = false;
  bool _sendButtonVisibility = false;
  String _layeredTextOnVideo = '';
  double _videoPosition = 0.0;
  double _videoDuration = 0.0;
  Color selectedTrackBorderColor = Colors.white;
  double? _previewHeight;

  // Canvas-based text overlay properties
  bool _useCanvasForTextOverlays = true;
  Size? _previewContainerSize;

  // Multi-video canvas properties
  bool _useMultiVideoCanvas = false;
  int _selectedCanvasVideoIndex = -1;
  final Map<String, VideoEditorController> _videoControllers = {};
  final Map<String, ui.Image> _imageCache =
      {}; // Global cache for image-based tracks
  Size _canvasSize =
      const Size(800, 600); // Default size, will be updated to container size

  // Undo/Redo stacks
  final List<EditOperation> _undoStack = [];
  final List<EditOperation> _redoStack = [];

  // Overlay video tracks
  final List<OverlayVideoTrackModel> _overlayVideoTracks = [];
  List<OverlayVideoTrackModel> get overlayVideoTracks => _overlayVideoTracks;

  // Canvas manipulation state
  String? _selectedMediaId; // Currently selected media for manipulation
  bool _showManipulationHandles = false;

  // Edit mode state for track trimming
  bool _isEditingTrack = false;
  TrackType? _editingTrackType;

  // Store edit mode per track type
  Map<TrackType, TrackEditMode> _trackEditModes = {
    TrackType.video: TrackEditMode.trim,
    TrackType.audio: TrackEditMode.trim,
    TrackType.text: TrackEditMode.trim,
  };

  // Toolbar add button visibility (show in timeline after first track added)
  bool _showAudioInTimeline = false;
  bool _showTextInTimeline = false;

  // Reorder mode state
  bool _isReorderMode = false;
  int? _reorderingTrackIndex;
  double?
      _reorderTouchPositionX; // Store global X position where long-press started

  // Video mute functionality now delegated to master timeline
  void toggleVideoMute(String videoId) {
    _masterTimelineController.toggleVideoMute(videoId);
    notifyListeners();
  }

  bool isVideoMuted(String videoId) {
    return _masterTimelineController.isVideoMuted(videoId);
  }

  // Getters
  VideoEditorController? get videoEditorController => _videoEditorController;
  MasterTimelineController get masterTimelineController =>
      _masterTimelineController;

  bool get isInitializingVideo => _isInitializingVideo;

  ScrollController? get videoScrollController => _videoScrollController;

  ScrollController? get audioScrollController => _audioScrollController;

  ScrollController? get textScrollController => _textScrollController;

  ScrollController? get bottomScrollController => _bottomScrollController;

  TextEditingController get textEditingController => _textEditingController;

  AudioPlayer? get audioController => _audioController;

  String? get selectedAudio => _selectedAudio;

  String? get currentVideoPath => _currentVideoPath;

  List<String> get assets => _assets;

  List<TextOverlay> get textOverlays => _textOverlays;

  String get currentFilter => _currentFilter;

  CanvasRatio get selectedCanvasRatio => _selectedCanvasRatio;

  EditMode get editMode => _editMode;

  double get trimStart => _trimStart;

  double get trimEnd => _trimEnd;

  double get audioTrimStart => _audioTrimStart;

  double get audioTrimEnd => _audioTrimEnd;

  Rect? get cropRect => _cropRect;

  int get rotation => _rotation;

  // Note: selectedTransition getter removed - use getTransitionBetweenTracks(index) instead

  double get playbackSpeed => _playbackSpeed;

  double get videoVolume => _videoVolume;

  double get audioVolume => _audioVolume;

  bool get isPlaying {
    // Use master timeline controller for sequential playback
    if (_videoTracks.isNotEmpty) {
      return _masterTimelineController.isPlaying;
    }
    return _isPlaying;
  }

  bool get isExtractingFrames => _isExtractingFrames;

  List<String> get framePaths => _framePaths;

  List<double> get waveformData => _waveformData;

  bool get textFieldVisibility => _textFieldVisibility;

  bool get sendButtonVisibility => _sendButtonVisibility;

  String get layeredTextOnVideo => _layeredTextOnVideo;

  double get videoPosition {
    // Use master timeline controller for sequential playback
    if (_videoTracks.isNotEmpty) {
      return _masterTimelineController.currentTimelinePosition;
    }
    return _videoPosition;
  }

  double get videoDuration => _masterTimelineController.totalDuration > 0
      ? _masterTimelineController.totalDuration
      : _videoDuration;

  // Canvas-related getters
  bool get useCanvasForTextOverlays => _useCanvasForTextOverlays;
  Size? get previewContainerSize => _previewContainerSize;

  // Multi-video canvas getters
  bool get useMultiVideoCanvas => _useMultiVideoCanvas;
  int get selectedCanvasVideoIndex => _selectedCanvasVideoIndex;
  Size get canvasSize => _canvasSize;
  Map<String, VideoEditorController> get videoControllers => _videoControllers;

  // Edit mode getters
  bool get isEditingTrack => _isEditingTrack;
  TrackType? get editingTrackType => _editingTrackType;
  TrackEditMode get trackEditMode => _editingTrackType != null
      ? _trackEditModes[_editingTrackType]!
      : TrackEditMode.trim;

  // Reorder mode getters
  bool get isReorderMode => _isReorderMode;
  int? get reorderingTrackIndex => _reorderingTrackIndex;
  double? get reorderTouchPositionX => _reorderTouchPositionX;

  // Check if a specific track type is being edited
  bool isEditingTrackType(TrackType trackType) {
    return _isEditingTrack && _editingTrackType == trackType;
  }

  // Check if a specific edit mode is active for a specific track type
  bool isEditMode(TrackEditMode mode, TrackType trackType) {
    return _trackEditModes[trackType] == mode;
  }

  // Add button visibility getters
  bool get showAudioInTimeline => true;
  bool get showTextInTimeline => true;

  /// Get count of active lanes (lanes with at least one track)
  /// Returns minimum of 1 to ensure UI always has a baseline height
  int getActiveLaneCount(TrackType type) {
    if (type == TrackType.audio) {
      // Count unique lane indices in audio tracks
      final uniqueLanes = _audioTracks.map((t) => t.laneIndex).toSet();
      return uniqueLanes.isEmpty ? 1 : uniqueLanes.length;
    } else if (type == TrackType.text) {
      // Count unique lane indices in text tracks
      final uniqueLanes = _textTracks.map((t) => t.laneIndex).toSet();
      return uniqueLanes.isEmpty ? 1 : uniqueLanes.length;
    }
    return 1; // Fallback
  }

  /// Dispose unused video controllers to free memory and prevent buffer overflow
  void disposeUnusedVideoControllers(List<String> keepControllerIds) {
    final controllersToDispose = <String>[];

    for (var entry in _videoControllers.entries) {
      if (!keepControllerIds.contains(entry.key)) {
        controllersToDispose.add(entry.key);
      }
    }

    for (var id in controllersToDispose) {
      var controller = _videoControllers[id];
      if (controller != null) {
        try {
          // Safely pause the controller if it's still initialized and playing
          if (controller.video.value.isInitialized &&
              controller.video.value.isPlaying) {
            controller.video.pause();
          }

          // Dispose the controller
          controller.dispose();
          _videoControllers.remove(id);
          print('🗑️ Disposed video controller: $id');
        } catch (e) {
          // Handle already disposed controllers gracefully
          print(
              '⚠️ Error disposing controller $id (likely already disposed): $e');
          _videoControllers.remove(id); // Remove from map anyway
        }
      }
    }
  }

  // Get video controller for specific track
  VideoEditorController? getVideoControllerForTrack(String trackId) {
    return _videoControllers[trackId];
  }

  /// Recreate a disposed controller for a specific track
  Future<VideoEditorController?> recreateControllerForTrack(
      String trackId) async {
    // Find the track
    VideoTrackModel? track;
    try {
      track = _videoTracks.firstWhere((t) => t.id == trackId);
    } catch (e) {
      track = null;
    }
    if (track == null) {
      print('❌ Track not found for recreation: $trackId');
      return null;
    }

    // Don't recreate if already exists and initialized
    final existing = _videoControllers[trackId];
    if (existing?.video.value.isInitialized == true) {
      print('✅ Controller already exists for $trackId');
      return existing;
    }

    print('🔄 Recreating controller for track $trackId');
    print(
        '   Processing file: ${track.processedFile.path} (original: ${track.originalFile.path})');

    try {
      final controller = VideoEditorController.file(track.processedFile);
      await controller.initialize();
      _videoControllers[trackId] = controller;

      print('✅ Controller recreated successfully');
      notifyListeners(); // Trigger UI rebuild

      return controller;
    } catch (e) {
      print('❌ Failed to recreate controller: $e');
      return null;
    }
  }

  // Add method to get current video time for canvas
  double get currentVideoTime {
    if (_videoEditorController?.video.value.isInitialized == true) {
      return _videoEditorController!.video.value.position.inMilliseconds /
          1000.0;
    }
    return 0.0;
  }

  Duration? get selectedAudioDuration => _audioDuration;

  List<VideoCaption> get captions => _captions;
  double _playbackPosition = 0.0;

  double get playbackPosition => _playbackPosition;
  Size? recommendedAspectRatio;

  List<VideoTrackModel> get videoTracks => _videoTracks;

  List<AudioTrackModel> get audioTracks => _audioTracks;

  List<TextTrackModel> get textTracks => _textTracks;

  int get selectedVideoTrackIndex => _selectedVideoTrackIndex;

  int get selectedAudioTrackIndex => _selectedAudioTrackIndex;

  int get selectedTextTrackIndex => _selectedTextTrackIndex;

  bool get isAnyVideoProcessing => _processingVideoTrackIndex != -1;

  // Active stretch tracking getters
  int get activeStretchTrackIndex => _activeStretchTrackIndex;
  double get activeStretchVisualDuration => _activeStretchVisualDuration;
  bool get isAnyTrackStretching => _activeStretchTrackIndex != -1;

  // Global image cache for image-based tracks (pre-caching)
  Map<String, ui.Image> get imageCache => _imageCache;

  void cacheImage(String trackId, ui.Image image) {
    _imageCache[trackId] = image;
  }

  void removeCachedImage(String trackId) {
    final image = _imageCache.remove(trackId);
    image?.dispose();
  }

  /// Get the index of the video track at current timeline position
  /// This is used for filter preview to match CapCut/Premiere behavior
  int get currentPlayingVideoTrackIndex {
    final position = _masterTimelineController.currentTimelinePosition;

    for (int i = 0; i < _videoTracks.length; i++) {
      final track = _videoTracks[i];
      if (position >= track.startTime && position < track.endTime) {
        return i;
      }
    }

    // Fallback: return first track or -1 if empty
    return _videoTracks.isNotEmpty ? 0 : -1;
  }

  // Preview height for text overlays
  double? get previewHeight => _previewHeight;

  void setPreviewHeight(double? height) {
    _previewHeight = height;
    notifyListeners();
  }

  void setUseCanvasForTextOverlays(bool value) {
    _useCanvasForTextOverlays = value;
    notifyListeners();
  }

  void setPreviewContainerSize(Size size) {
    _previewContainerSize = size;
    notifyListeners();
  }

  // Multi-video canvas methods
  void setUseMultiVideoCanvas(bool value) {
    _useMultiVideoCanvas = value;
    notifyListeners();
  }

  void setCanvasSize(Size size) {
    print(
        '🔶 SETTING PREVIEW CONTAINER SIZE - will trigger dynamic canvas recalculation');
    print(
        'Previous container size: ${_canvasSize.width} x ${_canvasSize.height}');
    print('New container size: ${size.width} x ${size.height}');
    final dynamicCanvasSize = _selectedCanvasRatio.getOptimalCanvasSize(size);
    print(
        'Calculated dynamic canvas size: ${dynamicCanvasSize.width} x ${dynamicCanvasSize.height}');

    // Store the preview container size for dynamic canvas calculations
    _canvasSize = size;

    // Recalculate asset positions and sizes based on new dynamic canvas
    _updateVideoPositionsForNewCanvasSize();

    notifyListeners();
  }

  /// Update video positions and sizes when canvas size changes
  void _updateVideoPositionsForNewCanvasSize() {
    print('🔄 UPDATING VIDEO POSITIONS FOR NEW CANVAS SIZE');
    final dynamicCanvasSize =
        _selectedCanvasRatio.getOptimalCanvasSize(_canvasSize);
    print('   Container size: ${_canvasSize.width} x ${_canvasSize.height}');
    print(
        '   Dynamic canvas size: ${dynamicCanvasSize.width} x ${dynamicCanvasSize.height}');
    print('   Number of tracks: ${_videoTracks.length}');

    for (int i = 0; i < _videoTracks.length; i++) {
      final track = _videoTracks[i];

      print('   Track $i (${track.id}):');
      print('     Old position: ${track.canvasPosition}');
      print('     Old size: ${track.canvasSize}');

      // Recalculate position and size based on new dynamic canvas dimensions
      final position = _calculateAutoPosition(i, dynamicCanvasSize);
      final size = _calculateAutoSize(track, dynamicCanvasSize);

      print('     New position: $position');
      print('     New size: $size');

      updateVideoTrackCanvasProperties(
        track.id,
        position: position,
        size: size,
      );

      print('     ✅ Track properties updated');
    }
  }

  void selectCanvasVideo(int index) {
    _selectedCanvasVideoIndex = index;
    notifyListeners();
  }

  /// Add a video controller for a track
  void addVideoControllerForTrack(
      String trackId, VideoEditorController controller) {
    _videoControllers[trackId] = controller;
    notifyListeners();
  }

  /// Remove video controller for a track
  void removeVideoControllerForTrack(String trackId) {
    final controller = _videoControllers[trackId];
    if (controller != null) {
      controller.dispose();
      _videoControllers.remove(trackId);
      notifyListeners();
    }
  }

  /// Update video track canvas properties
  void updateVideoTrackCanvasProperties(
    String trackId, {
    Offset? position,
    Size? size,
    double? scale,
    int? rotation,
    int? zIndex,
    Rect? cropRect,
    bool? visible,
    double? opacity,
  }) {
    final trackIndex = _videoTracks.indexWhere((track) => track.id == trackId);
    if (trackIndex >= 0) {
      final track = _videoTracks[trackIndex];

      // Log crop rect update if provided
      if (cropRect != null) {
        print('🔄 Updating crop rect for track $trackId:');
        print('   Previous crop: ${track.canvasCropRect}');
        print('   New crop: left=${cropRect.left.toStringAsFixed(4)}, '
            'top=${cropRect.top.toStringAsFixed(4)}, '
            'width=${cropRect.width.toStringAsFixed(4)}, '
            'height=${cropRect.height.toStringAsFixed(4)}');
      }

      // Convert Rect to CropModel if cropRect is provided
      CropModel? cropModel;
      if (cropRect != null) {
        // Assume the video size for now - this should ideally come from the video controller
        final videoController = _videoControllers[trackId];
        Size videoSize = const Size(1920, 1080); // Default fallback
        if (videoController?.video.value.isInitialized == true) {
          videoSize = videoController!.video.value.size;
        }

        cropModel = CropModel.fromRect(cropRect, videoSize, enabled: true);
      }

      final updatedTrack = track.copyWith(
        canvasPosition: position,
        canvasSize: size,
        canvasScale: scale,
        canvasRotation: rotation,
        canvasZIndex: zIndex,
        canvasCropModel: cropModel,
        canvasVisible: visible,
        canvasOpacity: opacity,
      );

      _videoTracks[trackIndex] = updatedTrack;

      // If a crop was applied, recalculate the video track size and position
      if (cropModel != null) {
        print('🔄 CROP APPLIED - Validating crop dimensions');
        print(
            '   Crop model: width=${cropModel.width}, height=${cropModel.height}');
        print('   Crop enabled: ${cropModel.enabled}');

        // Safety checks for crop model
        if (cropModel.enabled &&
            cropModel.width > 0 &&
            cropModel.height > 0 &&
            cropModel.width.isFinite &&
            cropModel.height.isFinite) {
          print(
              '   ✅ Crop dimensions are valid - proceeding with recalculation');
          final canvasSize =
              _selectedCanvasRatio.exportSize; // Use current canvas size
          print('   Canvas size: ${canvasSize.width} x ${canvasSize.height}');

          // Additional safety checks for canvas size
          if (canvasSize.width > 0 &&
              canvasSize.height > 0 &&
              canvasSize.width.isFinite &&
              canvasSize.height.isFinite) {
            final newAutoSize = _calculateAutoSize(updatedTrack, canvasSize);
            final newAutoPosition =
                _calculateAutoPosition(trackIndex, canvasSize);

            print(
                '   📐 New auto size after crop: ${newAutoSize.width} x ${newAutoSize.height}');
            print(
                '   📍 New auto position after crop: (${newAutoPosition.dx}, ${newAutoPosition.dy})');

            // Final safety checks for calculated values
            if (newAutoSize.width > 0 &&
                newAutoSize.height > 0 &&
                newAutoSize.width.isFinite &&
                newAutoSize.height.isFinite &&
                newAutoPosition.dx.isFinite &&
                newAutoPosition.dy.isFinite) {
              // Update the track again with the new auto-calculated size/position
              final finalTrack = updatedTrack.copyWith(
                canvasSize: newAutoSize,
                canvasPosition: newAutoPosition,
              );

              _videoTracks[trackIndex] = finalTrack;
              print('   ✅ Track size and position updated for cropped video');
            } else {
              print(
                  '   ⚠️ Invalid calculated size or position - skipping update');
              print('     Size: ${newAutoSize.width} x ${newAutoSize.height}');
              print(
                  '     Position: ${newAutoPosition.dx}, ${newAutoPosition.dy}');
            }
          } else {
            print('   ⚠️ Invalid canvas size - skipping crop recalculation');
            print('     Canvas: ${canvasSize.width} x ${canvasSize.height}');
          }
        } else {
          print('   ⚠️ Invalid crop dimensions - skipping recalculation');
          print(
              '     Width: ${cropModel.width} (finite: ${cropModel.width.isFinite})');
          print(
              '     Height: ${cropModel.height} (finite: ${cropModel.height.isFinite})');
        }
      }

      // Update master timeline controller with updated tracks (preserve position)
      _updateMasterTimeline(preservePosition: true);

      notifyListeners();
    }
  }

  /// Initialize multi-video canvas mode
  void initializeMultiVideoCanvas(Size canvasSize) {
    print('🔷 INITIALIZING MULTI-VIDEO CANVAS');
    print('Canvas size: ${canvasSize.width} x ${canvasSize.height}');
    setCanvasSize(canvasSize);
    setUseMultiVideoCanvas(true);

    // Initialize canvas positions for existing video tracks
    print('Initializing canvas positions for ${_videoTracks.length} tracks');
    for (int i = 0; i < _videoTracks.length; i++) {
      final track = _videoTracks[i];

      print('Track $i (${track.id}):');
      print('  Current position: ${track.canvasPosition}');
      print('  Current size: ${track.canvasSize}');

      // Always recalculate when canvas size changes to ensure proper fitting
      final currentCanvasArea = canvasSize.width * canvasSize.height;
      final trackCanvasArea = track.canvasSize.width * track.canvasSize.height;
      final areaDifferenceRatio =
          (currentCanvasArea - trackCanvasArea).abs() / trackCanvasArea;

      // Force recalculation on ANY size change (even 1%) to ensure canvas always gets updated
      final shouldRecalculate =
          true; // Always recalculate when setCanvasSize() is called

      if (shouldRecalculate) {
        print('  🔄 FORCING track recalculation (canvas size changed)');
        print(
            '  Canvas area: ${currentCanvasArea.toStringAsFixed(0)}, Track area: ${trackCanvasArea.toStringAsFixed(0)}');
        print(
            '  Area difference: ${(areaDifferenceRatio * 100).toStringAsFixed(1)}%');

        final dynamicCanvasSize =
            _selectedCanvasRatio.getOptimalCanvasSize(canvasSize);
        final position = _calculateAutoPosition(i, dynamicCanvasSize);
        final size = _calculateAutoSize(track, dynamicCanvasSize);

        print('  Setting position: $position, size: $size');
        updateVideoTrackCanvasProperties(
          track.id,
          position: position,
          size: size,
          zIndex: i,
        );
        print('  ✅ Canvas properties updated');
      }
    }
  }

  /// Calculate automatic position for a video on canvas
  Offset _calculateAutoPosition(int index, Size canvasSize) {
    print('🧮 CALCULATING POSITION for index $index');
    print('   Canvas size: ${canvasSize.width} x ${canvasSize.height}');
    print('   _useMultiVideoCanvas: $_useMultiVideoCanvas');
    print('   _videoTracks.length: ${_videoTracks.length}');

    // For sequential playback, center the video in the canvas
    if (!_useMultiVideoCanvas || _videoTracks.length == 1) {
      print('   → Taking SEQUENTIAL/SINGLE path');
      // Get the track to calculate its actual size
      if (index < _videoTracks.length) {
        final track = _videoTracks[index];
        final videoSize = _calculateAutoSize(track, canvasSize);

        // Center the video in the canvas
        final centerX = (canvasSize.width - videoSize.width) / 2;
        final centerY = (canvasSize.height - videoSize.height) / 2;

        final position = Offset(centerX, centerY);
        print('   Sequential/Single video - centering in canvas');
        print(
            '   Video size: ${videoSize.width.toStringAsFixed(1)} x ${videoSize.height.toStringAsFixed(1)}');
        print(
            '   Centered position: ${position.dx.toStringAsFixed(1)}, ${position.dy.toStringAsFixed(1)}');
        print('');
        return position;
      }
    }

    // Multi-video grid layout with boundary enforcement
    print('   → Taking MULTI-VIDEO GRID path');
    const margin = 20.0;
    const spacing = 10.0;

    // Calculate the actual size for this specific video
    if (index < _videoTracks.length) {
      final track = _videoTracks[index];
      final videoSize = _calculateAutoSize(track, canvasSize);

      // Calculate grid layout that fits within canvas bounds
      final availableWidth = canvasSize.width - (margin * 2);
      // final availableHeight = canvasSize.height - (margin * 2);

      // Calculate how many videos can fit per row based on actual video sizes
      final videosPerRow =
          max(1, (availableWidth / (videoSize.width + spacing)).floor());
      final row = index ~/ videosPerRow;
      final col = index % videosPerRow;

      // Calculate position ensuring it stays within canvas bounds
      final positionX = margin + col * (videoSize.width + spacing);
      final positionY = margin + row * (videoSize.height + spacing);

      // Enforce canvas boundaries
      final maxX = canvasSize.width - videoSize.width;
      final maxY = canvasSize.height - videoSize.height;

      final boundedPosition = Offset(
        positionX.clamp(0, max(0, maxX)),
        positionY.clamp(0, max(0, maxY)),
      );

      print(
          '   Multi-video grid: $videosPerRow videos per row, video $index at row $row, col $col');
      print(
          '   Video size: ${videoSize.width.toStringAsFixed(1)} x ${videoSize.height.toStringAsFixed(1)}');
      print(
          '   Calculated position: ${positionX.toStringAsFixed(1)}, ${positionY.toStringAsFixed(1)}');
      print(
          '   Bounded position: ${boundedPosition.dx.toStringAsFixed(1)}, ${boundedPosition.dy.toStringAsFixed(1)}');
      print('');

      return boundedPosition;
    }

    // Fallback if index is out of range
    return const Offset(20, 20);
  }

  /// Calculate automatic size for a video based on its aspect ratio (uses cropped dimensions if crop is enabled)
  Size _calculateAutoSize(VideoTrackModel track, Size canvasSize) {
    print('🔸 CALCULATING AUTO SIZE for track: ${track.id}');
    print('Canvas size: ${canvasSize.width} x ${canvasSize.height}');

    // Safety checks for canvas size
    if (canvasSize.width <= 0 ||
        canvasSize.height <= 0 ||
        !canvasSize.width.isFinite ||
        !canvasSize.height.isFinite) {
      print('⚠️ Invalid canvas size, using fallback: 400x300');
      canvasSize = const Size(400, 300);
    }

    // Try to get aspect ratio from video controller
    double aspectRatio = 16 / 9; // Default aspect ratio

    final controller = getVideoControllerForTrack(track.id);
    if (controller?.video.value.isInitialized == true) {
      final videoSize = controller!.video.value.size;
      if (videoSize.width > 0 && videoSize.height > 0) {
        // 🎯 CHECK IF VIDEO HAS CROP ENABLED - Use cropped aspect ratio instead of original
        if (track.hasCrop && track.canvasCropModel != null) {
          final cropModel = track.canvasCropModel!;
          aspectRatio = cropModel.width / cropModel.height;
          print('🌾 CROP DETECTED - Using cropped dimensions:');
          print('   Cropped size: ${cropModel.width} x ${cropModel.height}');
          print('   Cropped aspect ratio: $aspectRatio');
          print(
              '   Original video size: ${videoSize.width} x ${videoSize.height}');
        } else {
          aspectRatio = videoSize.width / videoSize.height;
          print(
              'Original video size: ${videoSize.width} x ${videoSize.height}');
          print('Video aspect ratio: $aspectRatio');
        }
      } else {
        print(
            '⚠️ Invalid video size from controller, using default aspect ratio');
      }
    } else {
      print(
          'Video controller not initialized, using default aspect ratio: $aspectRatio');
    }

    // Safety check for aspect ratio
    if (!aspectRatio.isFinite || aspectRatio <= 0) {
      print('⚠️ Invalid aspect ratio, using default 16:9');
      aspectRatio = 16 / 9;
    }

    // Calculate video size to optimally fill the dynamic canvas while maintaining aspect ratio
    final canvasAspect = canvasSize.width / canvasSize.height;

    double width, height;

    if (aspectRatio > canvasAspect) {
      // Video is wider than canvas - fit to canvas width
      width = canvasSize.width;
      height = width / aspectRatio;
      print('Video wider than canvas - fitting to width');
    } else {
      // Video is taller than canvas - fit to canvas height
      height = canvasSize.height;
      width = height * aspectRatio;
      print('Video taller than canvas - fitting to height');
    }

    // Calculate utilization and apply smart scaling for better canvas usage
    final baseUtilization =
        (width * height) / (canvasSize.width * canvasSize.height);
    print(
        'Base canvas utilization: ${(baseUtilization * 100).toStringAsFixed(1)}%');

    // For dynamic canvas, we can be more aggressive with sizing since canvas fits container optimally
    // Apply minimum utilization scaling if needed
    const minUtilization = 0.70; // Target at least 70% canvas usage
    if (baseUtilization < minUtilization) {
      final scaleFactor = sqrt(minUtilization / baseUtilization);
      width *= scaleFactor;
      height *= scaleFactor;

      // Ensure we don't exceed canvas bounds
      if (width > canvasSize.width || height > canvasSize.height) {
        final boundScale =
            min(canvasSize.width / width, canvasSize.height / height);
        width *= boundScale;
        height *= boundScale;
      }

      print(
          'Applied smart scaling: ${scaleFactor.toStringAsFixed(3)}x for better canvas utilization');
    }

    // Safety checks for final dimensions
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
      print('⚠️ Invalid calculated size, using safe fallback');
      width = canvasSize.width * 0.8;
      height = canvasSize.height * 0.8;
    }

    final finalSize = Size(width, height);
    final finalUtilization = (finalSize.width * finalSize.height) /
        (canvasSize.width * canvasSize.height);

    print(
        'Final video size: ${finalSize.width.toStringAsFixed(1)} x ${finalSize.height.toStringAsFixed(1)}');
    print(
        'Final canvas utilization: ${(finalUtilization * 100).toStringAsFixed(1)}%');
    print('');

    return finalSize;
  }

  // Add position tracking
  Timer? _positionTimer;

  // Audio controllers - moved from individual tracks to centralized management
  final Map<String, PlayerController> _audioControllers = {};

  toggleTextFieldVisibility(bool value) {
    _textFieldVisibility = value;
    notifyListeners();
  }

  toggleSendButtonVisibility(bool value) {
    _sendButtonVisibility = value;
    notifyListeners();
  }

  updateDisplayText(String value) {
    _layeredTextOnVideo = value;
    notifyListeners();
  }

  updateLoading(bool val) {
    loading = val;
    notifyListeners();
  }

  void setRecommendedAspectRatio(Size size) {
    recommendedAspectRatio = size;
    notifyListeners();
  }

  void setSelectedCanvasRatio(CanvasRatio canvasRatio) {
    _previousCanvasRatio =
        _selectedCanvasRatio; // Store old ratio before changing
    _selectedCanvasRatio = canvasRatio;
    // Update recommended aspect ratio based on selection
    recommendedAspectRatio = canvasRatio.exportSize;

    // Calculate dynamic canvas size for the new ratio using current container size
    final dynamicCanvasSize = _canvasSize.isEmpty
        ? canvasRatio.exportSize
        : // Fallback to export size if container not set yet
        canvasRatio.getOptimalCanvasSize(_canvasSize);

    print('🔄 Canvas ratio changed to ${canvasRatio.displayName}');
    print('   Container size: $_canvasSize');
    print('   Dynamic canvas size: $dynamicCanvasSize');
    print('   Export canvas size: ${canvasRatio.exportSize}');

    // Recalculate all asset positions and sizes using dynamic canvas size
    _recalculateAssetsForNewCanvasRatio(dynamicCanvasSize);

    notifyListeners();
  }

  /// Recalculate all asset positions and sizes when canvas ratio changes
  void _recalculateAssetsForNewCanvasRatio(Size newCanvasSize) {
    print('🔄 Recalculating assets for new canvas ratio: ${newCanvasSize}');

    // Recalculate video tracks
    for (int i = 0; i < _videoTracks.length; i++) {
      final track = _videoTracks[i];
      final newAutoSize = _calculateAutoSize(track, newCanvasSize);
      final newAutoPosition = _calculateAutoPosition(i, newCanvasSize);

      _videoTracks[i] = track.copyWith(
        canvasSize: newAutoSize,
        canvasPosition: newAutoPosition,
        // Keep existing scale, rotation, crop, and opacity settings
      );

      print(
          '   Updated video track ${track.id}: size=$newAutoSize, position=$newAutoPosition');
    }

    // Recalculate text tracks positions for new canvas
    for (int i = 0; i < _textTracks.length; i++) {
      final textTrack = _textTracks[i];

      // Get the PREVIOUS dynamic canvas size to calculate correct relative positions
      final oldCanvasRatio = _previousCanvasRatio ?? _selectedCanvasRatio;
      final currentDynamicCanvas = _canvasSize.isEmpty
          ? const Size(1080, 720)
          : // Fallback
          oldCanvasRatio.getOptimalCanvasSize(_canvasSize);

      print(
          '   Using old canvas ratio: ${oldCanvasRatio.displayName} for relative position calculation');

      // Keep text at the same relative position on the new canvas
      final relativeX = textTrack.position.dx / currentDynamicCanvas.width;
      final relativeY = textTrack.position.dy / currentDynamicCanvas.height;

      final newPosition = Offset(
        relativeX * newCanvasSize.width,
        relativeY * newCanvasSize.height,
      );

      print('   Text track ${textTrack.id}:');
      print(
          '     Old canvas: $currentDynamicCanvas, Old position: ${textTrack.position}');
      print('     New canvas: $newCanvasSize, New position: $newPosition');
      print('     Relative position: ($relativeX, $relativeY)');

      _textTracks[i] = textTrack.copyWith(position: newPosition);
    }

    // CRUCIAL: Update master timeline controller with the new track properties
    // Position is preserved automatically during track recalculation
    print('   Updating master timeline controller (position preserved)');
    _updateMasterTimeline(preservePosition: true);

    print(
        '✅ Asset recalculation completed for ${_videoTracks.length} videos and ${_textTracks.length} texts');
    print('   Master timeline controller updated with new track properties');
  }

  void setVideoTrackIndex(int index) {
    _selectedVideoTrackIndex = index;

    // If we have video tracks and an index is selected, jump to that video's start time
    if (_videoTracks.isNotEmpty && index >= 0 && index < _videoTracks.length) {
      final track = _videoTracks[index];
      _masterTimelineController.seekToTime(track.startTime.toDouble());

      // Enter edit mode only when a valid track is selected (index >= 0)
      enterEditMode(TrackType.video);
    }
  }

  void setAudioTrackIndex(int index,
      {TrackEditMode mode = TrackEditMode.trim}) {
    _selectedAudioTrackIndex = index;

    // Enter edit mode only when a valid track is selected (index >= 0)
    if (index >= 0) {
      enterEditMode(TrackType.audio, mode: mode);
    }
    notifyListeners();
  }

  void setTextTrackIndex(int index, {TrackEditMode mode = TrackEditMode.trim}) {
    _selectedTextTrackIndex = index;

    // Enter edit mode only when a valid track is selected (index >= 0)
    if (index >= 0) {
      enterEditMode(TrackType.text, mode: mode);
    }
    notifyListeners();
  }

  // Processing state control methods
  void setVideoProcessingState(int index) {
    _processingVideoTrackIndex = index;
    notifyListeners();
  }

  void clearVideoProcessingState() {
    _processingVideoTrackIndex = -1;
    notifyListeners();
  }

  // Edit mode control methods
  void enterEditMode(TrackType trackType,
      {TrackEditMode mode = TrackEditMode.trim}) {
    // ✅ Don't enter edit mode if currently in reorder mode
    if (_isReorderMode) {
      print('⚠️ Cannot enter edit mode while in reorder mode');
      print('   Please exit reorder mode first');
      return;
    }

    _isEditingTrack = true;
    _editingTrackType = trackType;
    _trackEditModes[trackType] = mode;
    notifyListeners();
  }

  void exitEditMode() {
    _isEditingTrack = false;
    _editingTrackType = null;
    // Reset all modes to default
    _trackEditModes = {
      TrackType.video: TrackEditMode.trim,
      TrackType.audio: TrackEditMode.trim,
      TrackType.text: TrackEditMode.trim,
    };
    // Clear selections to hide trim handles
    _selectedVideoTrackIndex = -1;
    _selectedAudioTrackIndex = -1;
    _selectedTextTrackIndex = -1;
    notifyListeners();
  }

  // Active stretch tracking methods
  void updateStretchProgress(int trackIndex, double visualDuration) {
    _activeStretchTrackIndex = trackIndex;
    _activeStretchVisualDuration = visualDuration;
    notifyListeners();
  }

  void clearStretchProgress() {
    _activeStretchTrackIndex = -1;
    _activeStretchVisualDuration = 0.0;
    notifyListeners();
  }

  // Get track at current timeline position
  VideoTrackModel? getVideoTrackAtPosition() {
    final position = _masterTimelineController.currentTimelinePosition;
    for (var track in _videoTracks) {
      if (position >= track.startTime.toDouble() &&
          position <= track.endTime.toDouble()) {
        return track;
      }
    }
    return null;
  }

  AudioTrackModel? getAudioTrackAtPosition() {
    final position = _masterTimelineController.currentTimelinePosition;
    for (var track in _audioTracks) {
      if (position >= track.trimStartTime && position <= track.trimEndTime) {
        return track;
      }
    }
    return null;
  }

  TextTrackModel? getTextTrackAtPosition() {
    final position = _masterTimelineController.currentTimelinePosition;
    for (var track in _textTracks) {
      if (position >= track.trimStartTime && position <= track.trimEndTime) {
        return track;
      }
    }
    return null;
  }

  // ===========================
  // Multi-Lane Utility Methods
  // ===========================

  /// Maximum number of simultaneous tracks allowed per type
  static const int maxLanes = 3;

  /// Get all audio tracks in a specific lane
  List<AudioTrackModel> getAudioTracksInLane(int laneIndex) {
    return _audioTracks.where((track) => track.laneIndex == laneIndex).toList()
      ..sort((a, b) => a.trimStartTime.compareTo(b.trimStartTime));
  }

  /// Get all text tracks in a specific lane
  List<TextTrackModel> getTextTracksInLane(int laneIndex) {
    return _textTracks.where((track) => track.laneIndex == laneIndex).toList()
      ..sort((a, b) => a.trimStartTime.compareTo(b.trimStartTime));
  }

  /// Compact text track lane indices to remove gaps
  /// Ensures lanes are always contiguous: [0, 1, 2, ...]
  /// Handles all edge cases: deletion, lane switching, sparse lanes
  void _compactTextLanes() {
    if (_textTracks.isEmpty) {
      print('📦 No text tracks to compact');
      return;
    }

    // Get sorted unique lane indices
    final uniqueLanes = _textTracks.map((t) => t.laneIndex).toSet().toList()
      ..sort();

    print('📦 Lane compaction check: current lanes = $uniqueLanes');

    // Check if already contiguous (0, 1, 2, ...)
    bool isContiguous = true;
    for (int i = 0; i < uniqueLanes.length; i++) {
      if (uniqueLanes[i] != i) {
        isContiguous = false;
        break;
      }
    }

    if (isContiguous) {
      print('✅ Lanes already contiguous, no compaction needed');
      return;
    }

    // Create mapping: old lane → new lane
    final laneMapping = <int, int>{};
    for (int i = 0; i < uniqueLanes.length; i++) {
      laneMapping[uniqueLanes[i]] = i;
    }

    print('📦 Compacting lanes: $laneMapping');

    // Reassign all tracks to compacted lanes
    for (int i = 0; i < _textTracks.length; i++) {
      final oldLane = _textTracks[i].laneIndex;
      final newLane = laneMapping[oldLane]!;

      if (oldLane != newLane) {
        _textTracks[i] = _textTracks[i].copyWith(
          laneIndex: newLane,
          updateTimestamp: false, // Housekeeping, don't update timestamp
        );
        print(
            '  📦 Track "${_textTracks[i].text}" moved: lane $oldLane → $newLane');
      }
    }

    print(
        '✅ Lane compaction complete: $uniqueLanes → ${List.generate(uniqueLanes.length, (i) => i)}');
  }

  /// Find smart placement for track in target lane
  /// Returns adjusted start time and duration, or null if no space available
  /// Automatically finds nearest gap if desired position is occupied
  ({double startTime, double duration})? findSmartPlacementInLane(
    int laneIndex,
    double desiredStartTime,
    double trackDuration,
  ) {
    // Get all tracks in target lane
    final tracksInLane = getTextTracksInLane(laneIndex)
      ..sort((a, b) => a.trimStartTime.compareTo(b.trimStartTime));

    // Empty lane - place at desired position (clamped to video duration)
    if (tracksInLane.isEmpty) {
      final clampedStart = desiredStartTime.clamp(0.0, _videoDuration);
      final maxDuration = min(trackDuration, _videoDuration - clampedStart);
      print('📍 Empty lane - placing at ${clampedStart.toStringAsFixed(1)}s');
      return maxDuration >= 1.0
          ? (startTime: clampedStart, duration: maxDuration)
          : null;
    }

    // Check if desired position has collision
    bool hasCollision = false;
    for (var track in tracksInLane) {
      if (desiredStartTime >= track.trimStartTime &&
          desiredStartTime < track.trimEndTime) {
        hasCollision = true;
        print(
            '⚠️ Collision detected at ${desiredStartTime.toStringAsFixed(1)}s with track ${track.trimStartTime.toStringAsFixed(1)}s-${track.trimEndTime.toStringAsFixed(1)}s');
        break;
      }
    }

    // No collision - check available space at desired position
    if (!hasCollision) {
      final availableDuration =
          getMaxAvailableTextDuration(laneIndex, desiredStartTime);
      if (availableDuration >= 1.0) {
        final finalDuration = min(trackDuration, availableDuration);
        print(
            '✅ No collision - placing at ${desiredStartTime.toStringAsFixed(1)}s with ${finalDuration.toStringAsFixed(1)}s duration');
        return (startTime: desiredStartTime, duration: finalDuration);
      }
    }

    // Collision detected - find all gaps in lane
    print(
        '🔍 Finding nearest gap to ${desiredStartTime.toStringAsFixed(1)}s...');
    List<({double start, double end})> gaps = [];

    // Gap before first track
    if (tracksInLane.first.trimStartTime > 0) {
      gaps.add((start: 0.0, end: tracksInLane.first.trimStartTime));
    }

    // Gaps between tracks
    for (int i = 0; i < tracksInLane.length - 1; i++) {
      final gapStart = tracksInLane[i].trimEndTime;
      final gapEnd = tracksInLane[i + 1].trimStartTime;
      if (gapEnd - gapStart >= 1.0) {
        gaps.add((start: gapStart, end: gapEnd));
      }
    }

    // Gap after last track
    final lastEnd = tracksInLane.last.trimEndTime;
    if (lastEnd < _videoDuration) {
      gaps.add((start: lastEnd, end: _videoDuration));
    }

    if (gaps.isEmpty) {
      print('❌ No gaps found in lane');
      return null;
    }

    // Find closest gap to desired position
    ({double start, double end})? bestGap;
    double minDistance = double.infinity;

    for (final gap in gaps) {
      double distance;
      if (desiredStartTime < gap.start) {
        // Gap is ahead
        distance = gap.start - desiredStartTime;
      } else if (desiredStartTime >= gap.end) {
        // Gap is behind
        distance = desiredStartTime - gap.end;
      } else {
        // Desired position is inside gap (shouldn't happen but handle it)
        distance = 0;
      }

      if (distance < minDistance) {
        minDistance = distance;
        bestGap = gap;
      }
    }

    if (bestGap == null) return null;

    final gapDuration = bestGap.end - bestGap.start;
    final finalDuration = min(trackDuration, gapDuration);

    if (finalDuration < 1.0) {
      print('❌ Nearest gap too small (${gapDuration.toStringAsFixed(1)}s)');
      return null;
    }

    print(
        '📍 Found nearest gap: ${bestGap.start.toStringAsFixed(1)}s-${bestGap.end.toStringAsFixed(1)}s (distance: ${minDistance.toStringAsFixed(1)}s)');
    return (startTime: bestGap.start, duration: finalDuration);
  }

  /// Compact audio track lane indices to remove gaps
  /// Ensures lanes are always contiguous: [0, 1, 2, ...]
  /// Handles all edge cases: deletion, lane switching, sparse lanes
  void _compactAudioLanes() {
    if (_audioTracks.isEmpty) {
      print('📦 No audio tracks to compact');
      return;
    }

    // Get sorted unique lane indices
    final uniqueLanes = _audioTracks.map((t) => t.laneIndex).toSet().toList()
      ..sort();

    print('📦 Audio lane compaction check: current lanes = $uniqueLanes');

    // Check if already contiguous (0, 1, 2, ...)
    bool isContiguous = true;
    for (int i = 0; i < uniqueLanes.length; i++) {
      if (uniqueLanes[i] != i) {
        isContiguous = false;
        break;
      }
    }

    if (isContiguous) {
      print('✅ Audio lanes already contiguous, no compaction needed');
      return;
    }

    // Create mapping: old lane → new lane
    final laneMapping = <int, int>{};
    for (int i = 0; i < uniqueLanes.length; i++) {
      laneMapping[uniqueLanes[i]] = i;
    }

    print('📦 Compacting audio lanes: $laneMapping');

    // Reassign all tracks to compacted lanes
    for (int i = 0; i < _audioTracks.length; i++) {
      final oldLane = _audioTracks[i].laneIndex;
      final newLane = laneMapping[oldLane]!;

      if (oldLane != newLane) {
        _audioTracks[i] = _audioTracks[i].copyWith(laneIndex: newLane);
        print('  📦 Audio track moved: lane $oldLane → $newLane');
      }
    }

    print(
        '✅ Audio lane compaction complete: $uniqueLanes → ${List.generate(uniqueLanes.length, (i) => i)}');
  }

  /// Find the first available lane for a new audio track at the specified time range
  /// Returns -1 if all lanes are occupied (max 3 lanes)
  int getAvailableAudioLane(double startTime, double endTime) {
    for (int lane = 0; lane < maxLanes; lane++) {
      if (!checkAudioLaneCollision(lane, startTime, endTime)) {
        return lane; // Found available lane
      }
    }
    return -1; // All lanes occupied
  }

  /// Find the first available lane for a new text track at the specified time range
  /// Returns -1 if all lanes are occupied (max 3 lanes)
  int getAvailableTextLane(double startTime, double endTime) {
    for (int lane = 0; lane < maxLanes; lane++) {
      if (!checkTextLaneCollision(lane, startTime, endTime)) {
        return lane; // Found available lane
      }
    }
    return -1; // All lanes occupied
  }

  /// Calculate maximum available duration for text at position in specific lane
  /// Returns duration considering:
  /// - Video end boundary
  /// - Next track collision in lane
  /// - Minimum 1 second requirement
  double getMaxAvailableTextDuration(int laneIndex, double startTime) {
    // Get all tracks in the target lane
    final tracksInLane = getTextTracksInLane(laneIndex)
      ..sort((a, b) => a.trimStartTime.compareTo(b.trimStartTime));

    // CRITICAL FIX: Check if startTime falls inside an existing track's time range
    for (var track in tracksInLane) {
      if (startTime >= track.trimStartTime && startTime < track.trimEndTime) {
        print(
            '🚫 Lane $laneIndex occupied at ${startTime.toStringAsFixed(1)}s by track: ${track.trimStartTime.toStringAsFixed(1)}s-${track.trimEndTime.toStringAsFixed(1)}s');
        return 0.0; // Position is occupied - no space available
      }
    }

    // Find next track after startTime
    TextTrackModel? nextTrack;
    for (var track in tracksInLane) {
      if (track.trimStartTime > startTime) {
        nextTrack = track;
        break;
      }
    }

    // Calculate max duration
    final double videoBoundary = _videoDuration - startTime;
    final double laneBoundary =
        nextTrack != null ? nextTrack.trimStartTime - startTime : videoBoundary;

    final availableDuration = min(videoBoundary, laneBoundary);
    print(
        '✅ Lane $laneIndex available at ${startTime.toStringAsFixed(1)}s: ${availableDuration.toStringAsFixed(1)}s');

    return availableDuration;
  }

  /// Find nearest available slot in any lane
  /// Searches forward first, then backward
  /// Returns null if no slot found with minimum duration
  ({int laneIndex, double startTime, double duration})?
      findNearestAvailableTextSlot(
    double currentPosition,
    double requiredDuration,
  ) {
    // Search parameters
    const double searchIncrement = 0.5; // Search every 0.5 seconds
    const double maxSearchDistance = 30.0; // Search up to 30 seconds away

    // Search forward
    for (double offset = searchIncrement;
        offset <= maxSearchDistance;
        offset += searchIncrement) {
      final testTime = currentPosition + offset;
      if (testTime >= _videoDuration) break;

      for (int lane = 0; lane < maxLanes; lane++) {
        final availableDuration = getMaxAvailableTextDuration(lane, testTime);
        if (availableDuration >= 1.0) {
          return (
            laneIndex: lane,
            startTime: testTime,
            duration: min(requiredDuration, availableDuration)
          );
        }
      }
    }

    // Search backward
    for (double offset = searchIncrement;
        offset <= maxSearchDistance;
        offset += searchIncrement) {
      final testTime = currentPosition - offset;
      if (testTime < 0) break;

      for (int lane = 0; lane < maxLanes; lane++) {
        final availableDuration = getMaxAvailableTextDuration(lane, testTime);
        if (availableDuration >= 1.0) {
          return (
            laneIndex: lane,
            startTime: testTime,
            duration: min(requiredDuration, availableDuration)
          );
        }
      }
    }

    return null; // No available slot found
  }

  /// Check if there's a collision in the specified audio lane at the given time range
  /// Returns true if collision exists, false if lane is clear
  bool checkAudioLaneCollision(
    int laneIndex,
    double startTime,
    double endTime, {
    String? excludeTrackId,
  }) {
    final tracksInLane = getAudioTracksInLane(laneIndex);

    for (var track in tracksInLane) {
      // Skip the track being edited
      if (excludeTrackId != null && track.id == excludeTrackId) {
        continue;
      }

      // Check for time overlap
      if (!(endTime <= track.trimStartTime || startTime >= track.trimEndTime)) {
        return true; // Collision detected
      }
    }

    return false; // No collision
  }

  /// Get maximum available audio duration at a given start time in a specific lane
  /// Factors in:
  /// - Next track collision in lane
  /// - Video duration boundary
  /// - Minimum 1 second requirement
  double getMaxAvailableAudioDuration(int laneIndex, double startTime) {
    // Get all tracks in the target lane
    final tracksInLane = getAudioTracksInLane(laneIndex)
      ..sort((a, b) => a.trimStartTime.compareTo(b.trimStartTime));

    // Check if startTime falls inside an existing track's time range
    for (var track in tracksInLane) {
      if (startTime >= track.trimStartTime && startTime < track.trimEndTime) {
        print(
            '🚫 Audio Lane $laneIndex occupied at ${startTime.toStringAsFixed(1)}s by track: ${track.trimStartTime.toStringAsFixed(1)}s-${track.trimEndTime.toStringAsFixed(1)}s');
        return 0.0; // Position is occupied - no space available
      }
    }

    // Find next track after startTime
    AudioTrackModel? nextTrack;
    for (var track in tracksInLane) {
      if (track.trimStartTime > startTime) {
        nextTrack = track;
        break;
      }
    }

    // Calculate max duration
    final double videoBoundary = _videoDuration - startTime;
    final double laneBoundary =
        nextTrack != null ? nextTrack.trimStartTime - startTime : videoBoundary;

    final availableDuration = min(videoBoundary, laneBoundary);
    print(
        '✅ Audio Lane $laneIndex available at ${startTime.toStringAsFixed(1)}s: ${availableDuration.toStringAsFixed(1)}s');

    return availableDuration;
  }

  /// Get the best available audio space at current timeline position
  /// Checks all lanes and returns lane with most available space
  /// Returns null if no lane has >= 1 second available
  ({int laneIndex, double duration})?
      getAvailableAudioSpaceAtCurrentPosition() {
    final currentPosition = _masterTimelineController.currentTimelinePosition;

    // Check space remaining in video
    final remainingVideoTime = _videoDuration - currentPosition;
    if (remainingVideoTime < 1.0) {
      print(
          '❌ Not enough video time remaining: ${remainingVideoTime.toStringAsFixed(1)}s < 1s');
      return null;
    }

    int bestLane = -1;
    double bestDuration = 0.0;

    // Check all 3 lanes for available space at current position
    for (int lane = 0; lane < maxLanes; lane++) {
      final availableDuration =
          getMaxAvailableAudioDuration(lane, currentPosition);

      print(
          '🔍 Audio Lane $lane at ${currentPosition.toStringAsFixed(1)}s: ${availableDuration.toStringAsFixed(1)}s available');

      if (availableDuration >= 1.0) {
        // Minimum 1 second required
        if (availableDuration > bestDuration) {
          bestLane = lane;
          bestDuration = availableDuration;
        }
      }
    }

    if (bestLane >= 0) {
      print(
          '✅ Best audio lane: $bestLane with ${bestDuration.toStringAsFixed(1)}s available');
      return (laneIndex: bestLane, duration: bestDuration);
    } else {
      print('❌ No audio lane has >= 1s available space at current position');
      return null;
    }
  }

  /// Check if text track can be added at current playback position
  /// Checks all lanes and returns lane with most available space
  /// Returns null if no lane has >= 1 second available
  ({int laneIndex, double duration})? getAvailableTextSpaceAtCurrentPosition() {
    final currentPosition = _masterTimelineController.currentTimelinePosition;

    // Check space remaining in video
    final remainingVideoTime = _videoDuration - currentPosition;
    if (remainingVideoTime < 1.0) {
      print(
          '❌ Not enough video time remaining: ${remainingVideoTime.toStringAsFixed(1)}s < 1s');
      return null;
    }

    int bestLane = -1;
    double bestDuration = 0.0;

    // Check all 3 lanes for available space at current position
    for (int lane = 0; lane < maxLanes; lane++) {
      final availableDuration =
          getMaxAvailableTextDuration(lane, currentPosition);

      print(
          '🔍 Text Lane $lane at ${currentPosition.toStringAsFixed(1)}s: ${availableDuration.toStringAsFixed(1)}s available');

      if (availableDuration >= 1.0) {
        // Minimum 1 second required
        if (availableDuration > bestDuration) {
          bestLane = lane;
          bestDuration = availableDuration;
        }
      }
    }

    if (bestLane >= 0) {
      print(
          '✅ Best text lane: $bestLane with ${bestDuration.toStringAsFixed(1)}s available');
      return (laneIndex: bestLane, duration: bestDuration);
    } else {
      print('❌ No text lane has >= 1s available space at current position');
      return null;
    }
  }

  /// Find smart placement for audio track in target lane
  /// Returns adjusted start time and duration, or null if no space available
  /// Automatically finds nearest gap if desired position is occupied
  ({double startTime, double duration})? findSmartPlacementInAudioLane(
    int laneIndex,
    double desiredStartTime,
    double trackDuration,
  ) {
    // Get all tracks in target lane
    final tracksInLane = getAudioTracksInLane(laneIndex)
      ..sort((a, b) => a.trimStartTime.compareTo(b.trimStartTime));

    // Empty lane - place at desired position (clamped to video duration)
    if (tracksInLane.isEmpty) {
      final clampedStart = desiredStartTime.clamp(0.0, _videoDuration);
      final maxDuration = min(trackDuration, _videoDuration - clampedStart);
      print(
          '📍 Empty audio lane - placing at ${clampedStart.toStringAsFixed(1)}s');
      return maxDuration >= 1.0
          ? (startTime: clampedStart, duration: maxDuration)
          : null;
    }

    // Check if desired position has collision
    bool hasCollision = false;
    for (var track in tracksInLane) {
      if (desiredStartTime >= track.trimStartTime &&
          desiredStartTime < track.trimEndTime) {
        hasCollision = true;
        print(
            '⚠️ Audio collision detected at ${desiredStartTime.toStringAsFixed(1)}s with track ${track.trimStartTime.toStringAsFixed(1)}s-${track.trimEndTime.toStringAsFixed(1)}s');
        break;
      }
    }

    // No collision - check available space at desired position
    if (!hasCollision) {
      final availableDuration =
          getMaxAvailableAudioDuration(laneIndex, desiredStartTime);
      if (availableDuration >= 1.0) {
        final finalDuration = min(trackDuration, availableDuration);
        print(
            '✅ No audio collision - placing at ${desiredStartTime.toStringAsFixed(1)}s with ${finalDuration.toStringAsFixed(1)}s duration');
        return (startTime: desiredStartTime, duration: finalDuration);
      }
    }

    // Collision detected - find all gaps in lane
    print(
        '🔍 Finding nearest audio gap to ${desiredStartTime.toStringAsFixed(1)}s...');
    List<({double start, double end})> gaps = [];

    // Gap before first track
    if (tracksInLane.first.trimStartTime > 0) {
      gaps.add((start: 0.0, end: tracksInLane.first.trimStartTime));
    }

    // Gaps between tracks
    for (int i = 0; i < tracksInLane.length - 1; i++) {
      final gapStart = tracksInLane[i].trimEndTime;
      final gapEnd = tracksInLane[i + 1].trimStartTime;
      if (gapEnd - gapStart >= 1.0) {
        gaps.add((start: gapStart, end: gapEnd));
      }
    }

    // Gap after last track
    final lastEnd = tracksInLane.last.trimEndTime;
    if (lastEnd < _videoDuration) {
      gaps.add((start: lastEnd, end: _videoDuration));
    }

    if (gaps.isEmpty) {
      print('❌ No audio gaps found in lane');
      return null;
    }

    // Find closest gap to desired position
    ({double start, double end})? bestGap;
    double minDistance = double.infinity;

    for (final gap in gaps) {
      double distance;
      if (desiredStartTime < gap.start) {
        // Gap is ahead
        distance = gap.start - desiredStartTime;
      } else if (desiredStartTime >= gap.end) {
        // Gap is behind
        distance = desiredStartTime - gap.end;
      } else {
        // Desired position is inside gap
        distance = 0;
      }

      if (distance < minDistance) {
        minDistance = distance;
        bestGap = gap;
      }
    }

    if (bestGap == null) return null;

    final gapDuration = bestGap.end - bestGap.start;
    final finalDuration = min(trackDuration, gapDuration);

    if (finalDuration < 1.0) {
      print(
          '❌ Nearest audio gap too small (${gapDuration.toStringAsFixed(1)}s)');
      return null;
    }

    print(
        '📍 Found nearest audio gap: ${bestGap.start.toStringAsFixed(1)}s-${bestGap.end.toStringAsFixed(1)}s (distance: ${minDistance.toStringAsFixed(1)}s)');
    return (startTime: bestGap.start, duration: finalDuration);
  }

  /// Check if there's a collision in the specified text lane at the given time range
  /// Returns true if collision exists, false if lane is clear
  bool checkTextLaneCollision(
    int laneIndex,
    double startTime,
    double endTime, {
    String? excludeTrackId,
  }) {
    final tracksInLane = getTextTracksInLane(laneIndex);

    for (var track in tracksInLane) {
      // Skip the track being edited
      if (excludeTrackId != null && track.id == excludeTrackId) {
        continue;
      }

      // Check for time overlap
      if (!(endTime <= track.trimStartTime || startTime >= track.trimEndTime)) {
        return true; // Collision detected
      }
    }

    return false; // No collision
  }

  /// Get all audio tracks active at a specific time point (across all lanes)
  /// Sorted by lane index for correct rendering order
  List<AudioTrackModel> getActiveAudioTracksAtTime(double time) {
    final activeTracks = _audioTracks.where((track) {
      return time >= track.trimStartTime && time < track.trimEndTime;
    }).toList();

    // Sort by lane index (lower lanes render first)
    activeTracks.sort((a, b) => a.laneIndex.compareTo(b.laneIndex));

    return activeTracks;
  }

  /// Get all text tracks active at a specific time point (across all lanes)
  /// Sorted by lane index for correct rendering order (higher lane = on top)
  List<TextTrackModel> getActiveTextTracksAtTime(double time) {
    final activeTracks = _textTracks.where((track) {
      return time >= track.trimStartTime && time < track.trimEndTime;
    }).toList();

    // Sort by lane index (lower lanes render first, higher lanes on top)
    activeTracks.sort((a, b) => a.laneIndex.compareTo(b.laneIndex));

    return activeTracks;
  }

  /// Get the number of active tracks at a specific time for a given lane
  int getActiveTrackCountAtTime(
      TrackType trackType, int laneIndex, double time) {
    switch (trackType) {
      case TrackType.audio:
        return getAudioTracksInLane(laneIndex)
            .where((track) =>
                time >= track.trimStartTime && time < track.trimEndTime)
            .length;
      case TrackType.text:
        return getTextTracksInLane(laneIndex)
            .where((track) =>
                time >= track.trimStartTime && time < track.trimEndTime)
            .length;
      case TrackType.video:
        return 0; // Video tracks don't use lane system
    }
  }

  // ===========================
  // End Multi-Lane Utility Methods
  // ===========================

  // Select track at current timeline position and enter edit mode
  void selectTrackAtPosition(TrackType trackType) {
    switch (trackType) {
      case TrackType.video:
        final track = getVideoTrackAtPosition();
        if (track != null) {
          final index = _videoTracks.indexOf(track);
          if (index >= 0) {
            setVideoTrackIndex(index);
          }
        }
        break;
      case TrackType.audio:
        final track = getAudioTrackAtPosition();
        if (track != null) {
          final index = _audioTracks.indexOf(track);
          if (index >= 0) {
            setAudioTrackIndex(index);
          }
        }
        break;
      case TrackType.text:
        final track = getTextTrackAtPosition();
        if (track != null) {
          final index = _textTracks.indexOf(track);
          if (index >= 0) {
            setTextTrackIndex(index);
          }
        }
        break;
    }
  }

  File? _originalVideoPath;
  // Initialize video
  Future<void> initializeVideo(String videoPath) async {
    try {
      _isInitializingVideo = true;
      notifyListeners();
      await _videoEditorController?.dispose();
      _videoEditorController = await VideoEditorController.file(
        File(videoPath),
      );
      await _videoEditorController?.initialize();
      await _videoEditorController?.video.setVolume(1.0);
      _isInitializingVideo = false;
      _trimEnd =
          _videoEditorController?.video.value.duration.inSeconds.toDouble() ??
              0.0;

      // Update video duration after initialization
      _videoDuration =
          _videoEditorController?.videoDuration.inSeconds.toDouble() ?? 0.0;

      // _controller?.addListener(() {
      //   _playbackPosition =
      //       _controller?.value.position.inSeconds.toDouble() ?? 0.0;
      //   notifyListeners();
      // });
      _currentVideoPath = videoPath;
      _originalVideoPath = File(videoPath);

      // Add position listener
      // _videoEditorController?.addListener(_onVideoPositionChanged);
      // Extract initial frames
      extractFrames();

      notifyListeners();
    } catch (err) {
      rethrow;
    }
  }

  Future<void> _initializeVideo(String path) async {
    await initializeVideo(path);
  }

  void togglePlay() {
    // Use master timeline controller for sequential playback
    if (_videoTracks.isNotEmpty) {
      _masterTimelineController.togglePlayPause();
      _isPlaying = _masterTimelineController.isPlaying;
      notifyListeners();
      return;
    }

    // Fallback to old behavior if no video tracks
    if (videoEditorController == null) return;

    try {
      // Check if controller is still valid and initialized
      if (!_videoEditorController!.video.value.isInitialized) return;

      if (isPlaying) {
        _videoEditorController?.video.pause();
      } else {
        _videoEditorController?.video.play();
      }
      _isPlaying = !_isPlaying;
      notifyListeners();
    } catch (e) {
      // Silently handle disposed controller errors during export
      debugPrint('Toggle play error (likely disposed controller): $e');
    }
  }

  void seekTo(double position) {
    if (_videoEditorController == null) return;

    // Clamp position within trim bounds
    position = position.clamp(_trimStart, _trimEnd);
    _videoEditorController?.video.seekTo(Duration(seconds: position.round()));
    notifyListeners();
  }

  // Asset management
  void addAsset(String asset) {
    _addToUndoStack(
      EditOperation(EditOperationType.asset, List<String>.from(_assets), [
        ..._assets,
        asset,
      ]),
    );
    _assets.add(asset);
    notifyListeners();
  }

  // Audio management
  Future<void> setAudio(String audio) async {
    _selectedAudio = audio;
    _audioController?.dispose();
    _audioController = AudioPlayer();
    final file = File(audio);
    await _audioController?.setSource(DeviceFileSource(file.path));

    // Get duration in a safe way
    final duration = await _audioController?.getDuration() ?? const Duration();
    _audioDuration = duration;
    _audioTrimEnd = duration.inSeconds.toDouble();

    // Generate waveform data
    await _generateWaveformData(audio);

    notifyListeners();
  }

  Future<void> _generateWaveformData(String audioPath) async {
    _isExtractingFrames = true;
    notifyListeners();

    try {
      final command =
          '-i $audioPath -f s16le -acodec pcm_s16le -ac 1 -ar 1000 pipe:1';
      final session = await FFmpegKit.execute(command);
      final output = await session.getOutput() ?? '';

      _waveformData = output
          .split('\n')
          .where((s) => s.isNotEmpty)
          .map((s) => double.parse(s))
          .toList();
    } finally {
      _isExtractingFrames = false;
      notifyListeners();
    }
  }

  // Edit mode
  void setEditMode(EditMode mode) {
    _editMode = mode;
    notifyListeners();
  }

  // Text overlays
  void addTextOverlay(TextOverlay overlay) {
    _addToUndoStack(
      EditOperation(
        EditOperationType.text,
        List<TextOverlay>.from(_textOverlays),
        [..._textOverlays, overlay],
      ),
    );
    _textOverlays.add(overlay);
    notifyListeners();
  }

  // Filters
  void applyFilter(String filter) {
    _addToUndoStack(
      EditOperation(EditOperationType.filter, _currentFilter, filter),
    );
    _currentFilter = filter;
    notifyListeners();
  }

  /// Set filter for a specific video track
  void setVideoTrackFilter(int index, String filter) {
    if (index < 0 || index >= _videoTracks.length) {
      print('⚠️ Invalid video track index for filter: $index');
      return;
    }

    print('🎨 Setting filter "$filter" for video track $index');
    _videoTracks[index] = _videoTracks[index].copyWith(filter: filter);

    // Sync updated tracks to master timeline controller so preview updates
    _masterTimelineController.initialize(
      tracks: _videoTracks,
      controllers: _videoControllers,
      audioTracks: _audioTracks,
      audioControllers: _audioControllers,
      preservePosition: true, // Keep current playback position
    );

    notifyListeners();
  }

  // crop
  Future<void> applyCrop() async {
    print('applyCrop called');
    print('_cropRect: $_cropRect');
    if (_cropRect == null || _videoEditorController == null) return;

    // Validate aspect ratio compliance
    if (recommendedAspectRatio != null) {
      final targetRatio =
          recommendedAspectRatio!.width / recommendedAspectRatio!.height;
      final currentRatio = _cropRect!.width / _cropRect!.height;

      if ((currentRatio - targetRatio).abs() > 0.01) {
        // Auto-adjust crop to match aspect ratio
        _cropRect = _constrainToAspectRatio(_cropRect!, targetRatio);
      }
    }
    final tempDir = await getTemporaryDirectory();
    final outputPath =
        '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_cropped_video.mp4';

    print(
      'Cropping with: width=${_cropRect!.width}, height=${_cropRect!.height}, left=${_cropRect!.left}, top=${_cropRect!.top}',
    );

    final command = '-i ${_videoEditorController!.video.dataSource} '
        '-filter:v "crop=${_cropRect!.width.toInt()}:'
        '${_cropRect!.height.toInt()}:'
        '${_cropRect!.left.toInt()}:'
        '${_cropRect!.top.toInt()}" '
        '-c:a copy $outputPath';

    final session = await FFmpegKit.execute(command);
    final logs = await session.getAllLogsAsString();
    print('applyCrop executed');
    print('FFmpeg logs: $logs');
    if (File(outputPath).existsSync()) {
      _currentVideoPath = outputPath;
      await initializeVideo(outputPath);
      _cropRect = null;
      notifyListeners();
    }
  }

  Rect _constrainToAspectRatio(Rect rect, double targetRatio) {
    final currentRatio = rect.width / rect.height;

    if (currentRatio > targetRatio) {
      return Rect.fromLTWH(
        rect.left,
        rect.top,
        rect.height * targetRatio,
        rect.height,
      );
    } else {
      return Rect.fromLTWH(
        rect.left,
        rect.top,
        rect.width,
        rect.width / targetRatio,
      );
    }
  }

  // void updateCropRect(Rect rect) {
  //   _cropRect = rect;
  //   notifyListeners();
  // }
  void refreshPreview() {
    if (_currentVideoPath != null) {
      initializeVideo(_currentVideoPath!);
    }
  }

  // caption
  void addCaption(VideoCaption caption) {
    _addToUndoStack(
      EditOperation(
        EditOperationType.caption,
        List<VideoCaption>.from(_captions),
        [..._captions, caption],
      ),
    );
    _captions.add(caption);
    notifyListeners();
  }

  // Trim controls
  void updateTrimValues(double start, double end) {
    print('🎬 updateTrimValues called: start=$start, end=$end');
    print('   Selected video track index: $_selectedVideoTrackIndex');
    print('   Total video tracks: ${_videoTracks.length}');

    _addToUndoStack(
      EditOperation(
        EditOperationType.trim,
        {'start': _trimStart, 'end': _trimEnd},
        {'start': start, 'end': end},
      ),
    );
    _trimStart = start;
    _trimEnd = end;

    // Apply trim to the selected video track and adjust timeline
    if (_selectedVideoTrackIndex >= 0 &&
        _selectedVideoTrackIndex < _videoTracks.length) {
      print('   ✅ Applying trim to selected track $_selectedVideoTrackIndex');
      _applyVideoTrimToTimeline(start, end);
    } else if (_videoTracks.length == 1) {
      // Handle single video case where selection might not be set
      print(
          '   ⚠️ No track selected but single video detected - applying to first track');
      _selectedVideoTrackIndex = 0;
      _applyVideoTrimToTimeline(start, end);
    } else {
      print('   ❌ Cannot apply trim - no valid track selected');
    }

    notifyListeners();
  }

  void updateAudioTrim(double start, double end) {
    _audioTrimStart = start;
    _audioTrimEnd = end;
    notifyListeners();
  }

  // Crop controls
  void updateCropRect(Rect rect) {
    print(
      'Provider updateCropRect: left=${rect.left}, top=${rect.top}, width=${rect.width}, height=${rect.height}',
    );
    print('Provider recommendedAspectRatio: $recommendedAspectRatio');

    // DISABLED: Don't constrain manual crops to recommended aspect ratio
    // This allows free cropping for text overlay positioning
    // if (recommendedAspectRatio != null) {
    //   final targetRatio =
    //       recommendedAspectRatio!.width / recommendedAspectRatio!.height;
    //   print('Provider constraining crop to aspect ratio: $targetRatio');
    //   final originalRect = rect;
    //   rect = _constrainToAspectRatio(rect, targetRatio);
    //   print(
    //       'Provider crop constrained: ${originalRect.width}x${originalRect.height} -> ${rect.width}x${rect.height}');
    // }

    print(
        'Provider crop NOT constrained - using original: ${rect.width}x${rect.height}');
    _addToUndoStack(EditOperation(EditOperationType.crop, _cropRect, rect));
    _cropRect = rect;
    notifyListeners();
  }

  // Future<void> applyCrop() async {
  //   if (_cropRect == null || _controller == null) return;
  //
  //   final aspectRatio = _cropRect!.width / _cropRect!.height;
  //   final command =
  //       '-i ${_controller!.dataSource} -vf "crop=${_cropRect!.width.toInt()}:${_cropRect!.height.toInt()}:${_cropRect!.left.toInt()}:${_cropRect!.top.toInt()}" -c:a copy ${_controller!.dataSource}_cropped.mp4';
  //
  //   await FFmpegKit.execute(command);
  //   await _initializeVideo('${_controller!.dataSource}_cropped.mp4');
  // }

  // Rotation controls
  void setRotation(int newRotation) {
    _addToUndoStack(
      EditOperation(EditOperationType.rotation, _rotation, newRotation),
    );
    _rotation = newRotation;
    notifyListeners();
  }

  // Method to get aspect ratio dimensions
  Size _getAspectRatioDimensions() {
    if (recommendedAspectRatio != null) {
      return recommendedAspectRatio!;
    }

    // Fallback to video dimensions if no recommended ratio is set
    if (_videoEditorController?.video.value.size != null) {
      return _videoEditorController!.video.value.size;
    }

    // Default aspect ratio (16:9 at 1080p)
    return const Size(1920, 1080);
  }

  // Updated combineVideos method with proper aspect ratio handling
  Future<void> combineVideos(List<String> assets) async {
    if (assets.isEmpty || _videoEditorController == null) return;

    final tempDir = await getTemporaryDirectory();
    final outputPath =
        '${tempDir.path}/combined_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final currentVideo = _currentVideoPath ?? _originalVideoPath!.path;

    // Get target dimensions
    final targetSize = _getAspectRatioDimensions();
    final targetWidth = targetSize.width.toInt();
    final targetHeight = targetSize.height.toInt();

    // Create temp files for image assets
    List<String> processedAssets = [];
    for (String asset in assets) {
      if ([
        "jpg",
        "jpeg",
        "png",
        "webp",
      ].contains(asset.split(".").last.toLowerCase())) {
        // Convert image to video with proper aspect ratio
        final imageVideoPath =
            '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_img_${processedAssets.length}.mp4';

        await FFmpegKit.execute(
          '-loop 1 -t 10 -i "$asset" '
          '-vf "scale=$targetWidth:$targetHeight:force_original_aspect_ratio=decrease,'
          'pad=$targetWidth:$targetHeight:(ow-iw)/2:(oh-ih)/2:color=black" '
          '-c:v h264 -preset medium -crf 23 -pix_fmt yuv420p '
          '-r 30 "$imageVideoPath"',
        );
        processedAssets.add(imageVideoPath);
      } else {
        // Scale video to match target aspect ratio
        final scaledVideoPath =
            '${tempDir.path}/scaled_${processedAssets.length}.mp4';

        await FFmpegKit.execute(
          '-i "$asset" '
          '-vf "scale=$targetWidth:$targetHeight:force_original_aspect_ratio=decrease,'
          'pad=$targetWidth:$targetHeight:(ow-iw)/2:(oh-ih)/2:color=black" '
          '-c:v h264 -preset medium -crf 23 -r 30 '
          '"$scaledVideoPath"',
        );
        processedAssets.add(scaledVideoPath);
      }
    }

    // Scale the current video to match target aspect ratio
    final scaledCurrentVideoPath = '${tempDir.path}/scaled_current.mp4';
    await FFmpegKit.execute(
      '-i "$currentVideo" '
      '-vf "scale=$targetWidth:$targetHeight:force_original_aspect_ratio=decrease,'
      'pad=$targetWidth:$targetHeight:(ow-iw)/2:(oh-ih)/2:color=black" '
      '-c:v h264 -preset medium -crf 23 -r 30 '
      '"$scaledCurrentVideoPath"',
    );

    // Create concat file including scaled current video
    final listPath =
        '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_files.txt';
    final allFiles = [scaledCurrentVideoPath, ...processedAssets];

    await File(listPath).writeAsString(
      allFiles
          .map((path) => "file '${path.replaceAll("'", "'\\''")}'")
          .join('\n'),
    );

    FFmpegSession session = await FFmpegKit.execute(
      '-f concat -safe 0 -i "$listPath" -c copy "$outputPath"',
    );

    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      await initializeVideo(outputPath);
      safePrint("NEW_VIDEO_${outputPath == currentVideo}: $outputPath");
    } else {
      listAllLogs(session);
    }
  }

  void updateAssets(List<String> newAssets) {
    _assets = newAssets;
    notifyListeners();
  }

  Future<void> applyRotation() async {
    if (_videoEditorController?.video == null || _rotation == 0) return;

    final tempDir = await getTemporaryDirectory();
    final outputPath = '${tempDir.path}/rotated_video.mp4';

    final command =
        '-i ${_videoEditorController!.video.dataSource} -vf "rotate=${_rotation * pi / 180}" -c:a copy $outputPath';
    await FFmpegKit.execute(command);

    await _initializeVideo(outputPath);
    // ✅ FIXED: Don't reset rotation to 0 - preserve it for preview system
    // _rotation = 0;  // ❌ REMOVED: This was preventing rotation detection
    notifyListeners();
  }

  // Frame extraction
  Future<void> extractFrames() async {
    if (_videoEditorController == null || _isExtractingFrames) return;

    _isExtractingFrames = true;
    notifyListeners();

    try {
      _framePaths = await FrameExtractor.extractFrames(
        videoPath: _videoEditorController!.video.dataSource,
        frameCount: 10,
        videoDuration: _videoEditorController!.video.value.duration,
      );
    } finally {
      _isExtractingFrames = false;
      notifyListeners();
    }
  }

  // Playback controls
  void setPlaybackSpeed(double speed) {
    _addToUndoStack(
      EditOperation(EditOperationType.speed, _playbackSpeed, speed),
    );
    _playbackSpeed = speed;
    _videoEditorController?.video.setPlaybackSpeed(speed);
    notifyListeners();
  }

  void setVideoVolume(double volume) {
    _videoVolume = volume;
    _videoEditorController?.video.setVolume(volume);
    notifyListeners();
  }

  void setAudioVolume(double volume) {
    _audioVolume = volume;
    _audioController?.setVolume(volume);
    notifyListeners();
  }

TransitionType? startTransition;
TransitionType? endTransition;

void setStartTransition(TransitionType type) {
  startTransition = type;
  applyStartTransition();
  notifyListeners();
}

void setEndTransition(TransitionType type) {
  endTransition = type;
  applyEndTransition();
  notifyListeners();
}

TransitionType? getStartTransition() => startTransition;
TransitionType? getEndTransition() => endTransition;

/// -------------------------------------------------------
/// APPLY START TRANSITION (virtual gap: START → track[0])
/// -------------------------------------------------------
void applyStartTransition() {
  if (_videoTracks.isEmpty) return;

  final firstTrack = _videoTracks.first.copyWith(
    transitionFromStart: startTransition,
    transitionFromStartDuration: 1.0,
  );

  _videoTracks[0] = firstTrack;

  masterTimelineController.initialize(
    tracks: _videoTracks,
    controllers: _videoControllers,
    audioTracks: _audioTracks,
    audioControllers: _audioControllers,
    preservePosition: true,
  );
}


/// -------------------------------------------------------
/// APPLY END TRANSITION (virtual gap: lastTrack → END)
/// -------------------------------------------------------
void applyEndTransition() {
  if (_videoTracks.isEmpty) return;

  final lastIndex = _videoTracks.length - 1;

  final lastTrack = _videoTracks[lastIndex].copyWith(
    transitionToEnd: endTransition,
    transitionToEndDuration: 1.0,
  );

  _videoTracks[lastIndex] = lastTrack;

  masterTimelineController.initialize(
    tracks: _videoTracks,
    controllers: _videoControllers,
    audioTracks: _audioTracks,
    audioControllers: _audioControllers,
    preservePosition: true,
  );
}



  // Per-asset Transitions
  /// Set transition from track at [trackIndex] to the next track
  void setVideoTrackTransitionToNext(int trackIndex, TransitionType type) {
    if (trackIndex < 0 || trackIndex >= _videoTracks.length - 1) {
      // Last track or invalid index - cannot have transitionToNext
      print('⚠️ Cannot set transition: invalid index or last track');
      return;
    }

    final updatedTrack = _videoTracks[trackIndex].copyWith(
      transitionToNext: type,
      transitionToNextDuration: 1.0,
    );

    _videoTracks[trackIndex] = updatedTrack;
    print('✅ Set transition for track $trackIndex: ${type.name}');
    print('   Transition details: ${type.name} (duration: 1.0s)');
    print(
        '   Track ${trackIndex} (${_videoTracks[trackIndex].totalDuration}s) → Track ${trackIndex + 1} (${_videoTracks[trackIndex + 1].totalDuration}s)');

    // Re-initialize master timeline controller to pick up the new transition
    masterTimelineController.initialize(
      tracks: _videoTracks,
      controllers: _videoControllers,
      audioTracks: _audioTracks,
      audioControllers: _audioControllers,
      preservePosition: true, // Keep current playback position
    );

    notifyListeners();
  }

  /// Remove transition from track at [trackIndex]
  void removeVideoTrackTransition(int trackIndex) {
    if (trackIndex < 0 || trackIndex >= _videoTracks.length) {
      print('⚠️ Cannot remove transition: invalid index');
      return;
    }

    final updatedTrack = _videoTracks[trackIndex].copyWith(
      transitionToNext: null,
    );

    _videoTracks[trackIndex] = updatedTrack;
    print('✅ Removed transition for track $trackIndex');
    notifyListeners();
  }

  /// Get transition for the gap between track N and track N+1
  TransitionType? getTransitionBetweenTracks(int trackIndex) {
    if (trackIndex < 0 || trackIndex >= _videoTracks.length) return null;
    return _videoTracks[trackIndex].transitionToNext;
  }

  // Undo/Redo functionality
  void _addToUndoStack(EditOperation operation) {
    _undoStack.push(operation);
    _redoStack.clear();
  }

  void undo() {
    if (_undoStack.isEmpty) return;

    final operation = _undoStack.pop();
    _redoStack.push(operation);
    _applyOperation(operation.reverse());
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;

    final operation = _redoStack.pop();
    _undoStack.push(operation);
    _applyOperation(operation);
    notifyListeners();
  }

  void _applyOperation(EditOperation operation) {
    switch (operation.type) {
      case EditOperationType.text:
        _textOverlays = operation.newState as List<TextOverlay>;
        break;
      case EditOperationType.filter:
        _currentFilter = operation.newState as String;
        break;
      case EditOperationType.trim:
        final Map<String, double> values =
            operation.newState as Map<String, double>;
        _trimStart = values['start']!;
        _trimEnd = values['end']!;
        break;
      case EditOperationType.crop:
        _cropRect = operation.newState as Rect?;
        break;
      case EditOperationType.rotation:
        _rotation = operation.newState as int;
        break;
      case EditOperationType.transition:
        // Note: Global transition undo/redo removed - now per-asset
        break;
      case EditOperationType.speed:
        _playbackSpeed = operation.newState as double;
        _videoEditorController?.video.setPlaybackSpeed(_playbackSpeed);
        break;
      case EditOperationType.asset:
        _assets = operation.newState as List<String>;
        break;
      case EditOperationType.caption:
        _captions = operation.newState as List<VideoCaption>;
        break;
      case EditOperationType.stretch:
        // Stretch operations are complex and require special handling
        // For now, we'll just trigger a full refresh
        notifyListeners();
        break;
    }
  }

  // Helper to write debug logs to a file
  Future<void> _writeLog(String message) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logFile = File('${dir.path}/video_export_debug.log');
      final timestamp = DateTime.now().toString();
      await logFile.writeAsString('[$timestamp] $message\n',
          mode: FileMode.append);
    } catch (e) {
      print('Failed to write log: $e');
    }
  }

  // Helper to probe video size (width, height)
  Future<Size?> probeVideoSize(String videoPath) async {
    final session = await FFmpegKit.execute('-i "$videoPath" -hide_banner');
    final output = await session.getOutput() ?? '';
    final logs = await session.getLogsAsString();
    final allOutput = output + logs;
    // Look for a line like: Stream #0:0: Video: h264 ... 1440x1440 ...
    final regex = RegExp(r'Video: [^,]+, [^,]+, (\d+)x(\d+)');
    final match = regex.firstMatch(allOutput);
    if (match != null) {
      final width = int.tryParse(match.group(1) ?? '0') ?? 0;
      final height = int.tryParse(match.group(2) ?? '0') ?? 0;
      if (width > 0 && height > 0) {
        return Size(width.toDouble(), height.toDouble());
      }
    }
    return null;
  }

  // Helper: Ensure a video file has audio (add silent audio if missing)
  Future<File> ensureAudio(File videoFile) async {
    // Check if video has audio
    final session =
        await FFmpegKit.execute('-i "${videoFile.path}" -hide_banner');
    final output = await session.getOutput() ?? '';
    final logs = await session.getLogsAsString() ?? '';
    final allOutput = output + logs;
    if (allOutput.contains('Audio:')) {
      return videoFile;
    }
    // Add silent audio
    final tempDir = await getTemporaryDirectory();
    final outputPath =
        '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_withaudio.mp4';
    final command =
        '-y -i "${videoFile.path}" -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000 -shortest -c:v copy -c:a aac "$outputPath"';
    print('Adding silent audio: $command');
    final addSession = await FFmpegKit.execute(command);
    final returnCode = await addSession.getReturnCode();
    if (ReturnCode.isSuccess(returnCode)) {
      print('Silent audio added: $outputPath');
      return File(outputPath);
    } else {
      print('Failed to add silent audio, using original: ${videoFile.path}');
      return videoFile;
    }
  }

  /// Combine all video segments into a single video file (no transitions)
  Future<String?> combineSegments(List<VideoTrackModel> videoTracks) async {
    if (videoTracks.isEmpty) return null;
    final tempDir = await getTemporaryDirectory();
    final outputPath =
        '${tempDir.path}/combined_${DateTime.now().millisecondsSinceEpoch}.mp4';

    print('=== Starting combineSegments with mute processing ===');
    print('Number of video tracks: ${videoTracks.length}');

    // First, process segments for mute state
    List<File> processedSegments = [];
    for (int i = 0; i < videoTracks.length; i++) {
      final track = videoTracks[i];
      final isMuted = isVideoMuted(track.id);

      print(
          'Processing segment $i: id=${track.id}, muted=$isMuted, path=${track.processedFile.path}');

      if (isMuted) {
        // Step 1: Set original audio volume to 0
        final tempMutedPath =
            '${tempDir.path}/temp_muted_segment_${i}_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final volumeMuteCmd =
            '-y -i "${track.processedFile.path}" -af "volume=0" -c:v copy -c:a aac "$tempMutedPath"';
        print('Muting original audio for segment $i: $volumeMuteCmd');
        final muteSession = await FFmpegKit.execute(volumeMuteCmd);
        final muteReturnCode = await muteSession.getReturnCode();
        if (!ReturnCode.isSuccess(muteReturnCode)) {
          print('Failed to mute original audio for segment $i, using original');
          processedSegments.add(track.processedFile);
          continue;
        }

        // Step 2: Add silent audio using anullsrc
        final mutedPath =
            '${tempDir.path}/muted_segment_${i}_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final anullsrcCmd =
            '-y -i "$tempMutedPath" -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000 -shortest -c:v copy -c:a aac "$mutedPath"';
        print('Adding silent audio for segment $i: $anullsrcCmd');
        final anullsrcSession = await FFmpegKit.execute(anullsrcCmd);
        final anullsrcReturnCode = await anullsrcSession.getReturnCode();
        if (ReturnCode.isSuccess(anullsrcReturnCode)) {
          processedSegments.add(File(mutedPath));
          print('Muted segment $i processed successfully: $mutedPath');
          // Verify the muted segment has silent audio
          final verifySession =
              await FFmpegKit.execute('-i "$mutedPath" -hide_banner');
          final verifyOutput = await verifySession.getOutput() ?? '';
          final verifyLogs = await verifySession.getLogsAsString();
          final allVerifyOutput = verifyOutput + verifyLogs;
          print(
              'Muted segment $i audio check: ${allVerifyOutput.contains('Audio:') ? 'Has audio stream' : 'No audio stream'}');
          if (allVerifyOutput.contains('Audio:')) {
            print(
                'Muted segment $i audio details: ${allVerifyOutput.split('Audio:').last.split('\n').first}');
          }
        } else {
          print('Failed to add silent audio for segment $i, using original');
          processedSegments.add(track.processedFile);
        }
      } else {
        // Not muted, use original file
        final fileWithAudio = await ensureAudio(track.processedFile);
        processedSegments.add(fileWithAudio);
        print('Segment $i processed (not muted): ${fileWithAudio.path}');
        // Verify the segment has audio
        final verifySession =
            await FFmpegKit.execute('-i "${fileWithAudio.path}" -hide_banner');
        final verifyOutput = await verifySession.getOutput() ?? '';
        final verifyLogs = await verifySession.getLogsAsString() ?? '';
        final allVerifyOutput = verifyOutput + verifyLogs;
        print(
            'Segment $i audio stream check: ${allVerifyOutput.contains('Audio:') ? 'Has audio stream' : 'No audio stream'}');
        if (allVerifyOutput.contains('Audio:')) {
          print(
              'Segment $i audio details: ${allVerifyOutput.split('Audio:').last.split('\n').first}');
        }
      }
    }

    // Ensure all segments have audio
    List<File> audioSafeSegments = [];
    for (int i = 0; i < processedSegments.length; i++) {
      final fileWithAudio = await ensureAudio(processedSegments[i]);
      audioSafeSegments.add(fileWithAudio);
      print('Segment $i audio-safe: ${fileWithAudio.path}');
      // Print audio stream info for verification
      final verifySession =
          await FFmpegKit.execute('-i "${fileWithAudio.path}" -hide_banner');
      final verifyOutput = await verifySession.getOutput() ?? '';
      final verifyLogs = await verifySession.getLogsAsString();
      final allVerifyOutput = verifyOutput + verifyLogs;
      print(
          'Segment $i audio stream check: ${allVerifyOutput.contains('Audio:') ? 'Has audio stream' : 'No audio stream'}');
      if (allVerifyOutput.contains('Audio:')) {
        print(
            'Segment $i audio details: ${allVerifyOutput.split('Audio:').last.split('\n').first}');
      }
    }

    // Create a file list for FFmpeg concat
    final listPath =
        '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_input_list.txt';
    final fileList = audioSafeSegments
        .map((file) => "file '${file.path.replaceAll("'", "'\\''")}'")
        .join('\n');
    await File(listPath).writeAsString(fileList);

    // Use -map 0:v -map 0:a? to ensure audio is included if present
    final command =
        '-y -f concat -safe 0 -i "$listPath" -map 0:v -map 0:a? -c:v libx264 -preset ultrafast -c:a aac -b:a 800k "$outputPath"';
    print('Combining segments command: $command');
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    if (ReturnCode.isSuccess(returnCode)) {
      print('Segments combined successfully: $outputPath');
      // Check if output has audio
      bool hasAudio = await _hasAudioStream(outputPath);
      print('Combined output has audio: $hasAudio');
      if (!hasAudio) {
        // Add silent audio as fallback
        print('No audio detected in combined output, adding silent audio.');
        final fileWithAudio = await ensureAudio(File(outputPath));
        print('Silent audio added to combined output: ${fileWithAudio.path}');
        return fileWithAudio.path;
      }
      return outputPath;
    } else {
      final logs = await session.getOutput();
      print('Failed to combine segments: $logs');
      return null;
    }
  }

  // Helper to check if a video file has an audio stream
  Future<bool> _hasAudioStream(String filePath) async {
    final session = await FFmpegKit.execute('-i "$filePath" -hide_banner');
    final output = await session.getOutput() ?? '';
    final logs = await session.getLogsAsString() ?? '';
    final allOutput = output + logs;
    return allOutput.contains('Audio:');
  }

  /// Only merge audio tracks with the already combined video
  Future<String?> mergeMultipleAudioToVideo(
    BuildContext context, {
    required String combinedVideoPath,
  }) async {
    final tempDir = await getTemporaryDirectory();

    await _writeLog('=== Starting mergeMultipleAudioToVideo ===');
    await _writeLog('Number of audio tracks: ${_audioTracks.length}');
    print('=== Starting mergeMultipleAudioToVideo ===');
    print('Number of audio tracks: ${_audioTracks.length}');

    // If no additional audio tracks, return the combined video
    if (_audioTracks.isEmpty) {
      await _writeLog('No additional audio tracks, returning combined video');
      print('No additional audio tracks, returning combined video');
      return combinedVideoPath;
    }

    // Merge additional audio tracks with the combined video (audio is guaranteed to be present)
    await _writeLog('Merging additional audio tracks with combined video...');
    print('Merging additional audio tracks with combined video...');
    return await _mergeAudioTracksWithVideo(combinedVideoPath);
  }

  Future<int> getMediaDuration(String filePath) async {
    final session = await FFmpegKit.execute('-i "$filePath" 2>&1');
    final logs = await session.getOutput();

    RegExp durationRegex = RegExp(r"Duration:\s(\d+):(\d+):(\d+)");
    final match = durationRegex.firstMatch(logs ?? '');

    if (match != null) {
      int hours = int.parse(match.group(1)!);
      int minutes = int.parse(match.group(2)!);
      int seconds = int.parse(match.group(3)!);
      return (hours * 3600) + (minutes * 60) + seconds;
    }

    return 0;
  }

  Future<File?> trimGeneratedAudio({
    required File audioFile,
    required double audioDuration,
    required double startDuration,
    required double endDuration,
  }) async {
    final String inputPath = audioFile.path;
    final Directory tempDir = await getTemporaryDirectory();
    final String outputPath =
        "${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_processed_audio.mp3";

    String command;
    double trimDuration = endDuration - startDuration;

    if (!File(inputPath).existsSync()) {
      print("Error: Input file does not exist: $inputPath");
      return null;
    }

    if (audioDuration > trimDuration) {
      command =
          "-i '$inputPath' -ss $startDuration -t $trimDuration -c copy $outputPath";
    } else {
      return audioFile;
    }

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      final int outputDuration = await getMediaDuration(outputPath);
      if (outputDuration > trimDuration) {
        final String trimmedOutputPath =
            "${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_trimmed_audio.mp3";
        final sessionTrim = await FFmpegKit.execute(
          "-i '$outputPath' -t $trimDuration -c copy $trimmedOutputPath",
        );
        return ReturnCode.isSuccess(await sessionTrim.getReturnCode())
            ? File(trimmedOutputPath)
            : null;
      }
      return File(outputPath);
    }
    return null;
  }

  Future<File?> trimAudio({
    required File audioFile,
    required double audioDuration,
    required double startDuration,
    required double endDuration,
  }) async {
    final String inputPath = audioFile.path;
    final Directory tempDir = await getTemporaryDirectory();
    final String outputPath =
        "${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_processed_audio.mp3";

    if (!File(inputPath).existsSync()) {
      print("Error: Input file does not exist: $inputPath");
      return null;
    }

    double trimDuration = endDuration - startDuration;
    if (trimDuration <= 0) {
      print("Error: Invalid trim duration: $trimDuration");
      return audioFile;
    }

    String command;

    if (audioDuration > trimDuration) {
      // Trim audio
      command =
          "-i '$inputPath' -ss $startDuration -t $trimDuration -c:a aac -b:a 128k '$outputPath'";
    } else if (audioDuration < trimDuration) {
      // Loop audio to match duration
      int loops = (trimDuration / audioDuration).ceil();
      command =
          "-stream_loop $loops -i '$inputPath' -t $trimDuration -c:a aac -b:a 128k '$outputPath'";
    } else {
      // Duration matches, just re-encode
      command = "-i '$inputPath' -c:a aac -b:a 128k '$outputPath'";
    }

    print('Trim audio command: $command');
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      return File(outputPath);
    } else {
      final logs = await session.getOutput();
      print('Audio trim error: $logs');
      return null;
    }
  }

  // Additional helper method to validate audio files
  Future<bool> validateAudioFile(File audioFile) async {
    if (!audioFile.existsSync()) {
      print('Audio file does not exist: ${audioFile.path}');
      return false;
    }

    final session = await FFmpegKit.execute(
      '-i "${audioFile.path}" -hide_banner -t 1 -f null - 2>&1',
    );
    final output = await session.getOutput() ?? '';

    if (output.contains('Invalid data found') ||
        output.contains('No such file')) {
      print('Invalid audio file: ${audioFile.path}');
      return false;
    }

    return true;
  }

  Future<void> combineMediaFiles(
    List<File> reorderFiles,
    List<int> totalDuration,
  ) async {
    // updateLoading(true);
    final (
      File? resultVideo,
      List<(File, File)>? processedFiles,
    ) = await EditorVideoController.combineMediaFiles(
      reorderFiles,
      totalDuration: totalDuration,
      outputHeight: recommendedAspectRatio?.height.toInt() ?? 0,
      outputWidth: recommendedAspectRatio?.width.toInt() ?? 0,
    );
    if (resultVideo != null && processedFiles != null) {
      await reset(
        resultVideo.path,
        originalFile: reorderFiles,
        processedFile: processedFiles.map((e) => e.$2).toList(),
      );
    }
  }

  // reset
  Future<void> reset(
    String videoPath, {
    Size? recommendedSize,
    required List<File> processedFile,
    required List<File> originalFile,
    List<AudioTrackModel>? preserveAudioTracks,
    List<TextTrackModel>? preserveTextTracks,
    String? preserveOverlayText,
    Map<String, bool>? preserveMuteStates,
  }) async {
    // DEBUG LOGGING
    print('DEBUG: reset called with:');
    print('  originalFile:');
    for (var f in originalFile) print('    ' + f.path);
    print('  processedFile:');
    for (var f in processedFile) print('    ' + f.path);
    if (preserveMuteStates != null) {
      print('  preserveMuteStates: $preserveMuteStates');
    }

    // Save current mute states before clearing anything - now handled by master timeline

    // Clean up old resources
    _audioController?.dispose();

    // Reset all values to default
    _videoVolume = 1.0;
    _audioVolume = 1.0;
    // ✅ FIXED: Don't reset rotation to 0 - preserve it for preview system
    // _rotation = 0;  // ❌ REMOVED: This was preventing rotation detection
    _trimStart = 0.0;
    _trimEnd = 0.0;
    // Note: Global transition reset removed - now per-asset
    _currentFilter = 'none';
    _cropRect = null;

    // Only clear if not preserving
    if (preserveOverlayText != null) {
      _layeredTextOnVideo = preserveOverlayText;
    } else {
      _layeredTextOnVideo = '';
    }

    if (preserveAudioTracks != null) {
      _audioTracks = List.from(preserveAudioTracks);
    } else {
      _audioTracks.clear();
    }

    if (preserveTextTracks != null) {
      _textTracks = List.from(preserveTextTracks);
    } else {
      _textTracks.clear();
    }

    // Use preserved mute states if provided (mute states now managed by master timeline)
    final muteStatesToPreserve = preserveMuteStates ?? <String, bool>{};
    print('Using mute states for preservation: $muteStatesToPreserve');

    await _generateVideoTracks(
      originalFile: originalFile,
      processedFile: processedFile,
      preserveMuteStates: muteStatesToPreserve,
    );

    // Initialize with new video
    await initializeVideo(videoPath);
    await initializeOrResetControllers();
    // For sequential playback, use sum of individual video tracks instead of combined video duration
    _videoDuration = _videoTracks.fold(0.0, (sum, t) {
      final duration = t.isImageBased && t.customDuration != null
          ? t.customDuration!
          : t.totalDuration.toDouble();
      return sum + duration;
    });
    print('🎯 Sequential playback initial duration: ${_videoDuration}s');

    // Don't use listenVideoPosition for sequential playback - master controller handles it
    if (_videoTracks.isEmpty) {
      videoEditorController?.video.removeListener(listenVideoPosition);
      videoEditorController?.video.addListener(listenVideoPosition);
    } else {
      // Remove the listener for sequential playback mode
      videoEditorController?.video.removeListener(listenVideoPosition);
    }
    // updateLoading(false);
    if (recommendedSize != null) {
      setRecommendedAspectRatio(recommendedSize);
    }

    // Verify tracks were created properly
    print(
        'Video tracks after reset: ${_videoTracks.map((t) => '${t.id}: ${t.originalFile.path}').toList()}');
  }

  listenVideoPosition() {
    try {
      // Check if controller is still valid
      if (_videoEditorController == null) return;

      // For sequential playback, use master timeline controller position
      if (_videoTracks.isNotEmpty) {
        // Position is managed by master timeline controller
        _videoPosition = _masterTimelineController.currentTimelinePosition;
      } else {
        _videoPosition =
            (_videoEditorController?.videoPosition.inSeconds ?? 0).toDouble();
      }
      // print('Preview position: [33m[1m[4m[7m${_videoPosition}s[0m');
      // print('Segments:');
      // for (var t in _videoTracks) {
      //   print('  id: [36m${t.id}[0m, start: ${t.startTime}, end: ${t.endTime}');
      // }
      // Find the current video segment based on playback position
      VideoTrackModel? currentTrack;
      if (_videoTracks.isNotEmpty) {
        try {
          currentTrack = _videoTracks.firstWhere(
            (track) =>
                _videoPosition >= track.startTime &&
                _videoPosition < track.endTime,
          );
        } catch (e) {
          currentTrack = _videoTracks.last;
        }
      }
      if (currentTrack != null) {
        // print('Current segment: id: [32m${currentTrack.id}[0m, start: ${currentTrack.startTime}, end: ${currentTrack.endTime}, muted: ${isVideoMuted(currentTrack.id)}');
        final isMuted = isVideoMuted(currentTrack.id);
        _videoEditorController?.video.setVolume(isMuted ? 0.0 : 1.0);
      }

      notifyListeners();
    } catch (e) {
      // Silently handle disposed controller errors during export
      debugPrint(
          'Video position listener error (likely disposed controller): $e');
    }
  }

  Future<void> initializeOrResetControllers() async {
    _videoEditorController?.video.pause();

    // Get current position to avoid seeking to the same position
    final currentPosition =
        _videoEditorController?.video.value.position.inSeconds ?? 0;

    // Only seek to 0 if we're not already at position 0 to avoid blank screen issue
    if (currentPosition != 0) {
      await _videoEditorController?.video.seekTo(Duration(seconds: 0));
    } else {
      // If already at position 0, seek to a very small position and back to ensure proper rendering
      await _videoEditorController?.video.seekTo(Duration(milliseconds: 100));
      await Future.delayed(Duration(
          milliseconds: 50)); // Small delay to ensure frame is rendered
      await _videoEditorController?.video.seekTo(Duration(seconds: 0));
    }

    _linkedScrollControllerGroup.resetScroll();
    if (_videoScrollController == null)
      _videoScrollController = await _linkedScrollControllerGroup.addAndGet();
    if (_audioScrollController == null)
      _audioScrollController = await _linkedScrollControllerGroup.addAndGet();
    if (_textScrollController == null)
      _textScrollController = await _linkedScrollControllerGroup.addAndGet();
    if (_bottomScrollController == null)
      _bottomScrollController = await _linkedScrollControllerGroup.addAndGet();
    // Reset the scroll group and create fresh linked controllers
    // _linkedScrollControllerGroup.resetScroll();
    // _videoScrollController = await _linkedScrollControllerGroup.addAndGet();
    // _audioScrollController = await _linkedScrollControllerGroup.addAndGet();
    // _textScrollController = await _linkedScrollControllerGroup.addAndGet();
    // _bottomScrollController = await _linkedScrollControllerGroup.addAndGet();

    // Initialize audio controllers for existing audio tracks
    if (_audioTracks.isNotEmpty) {
      await _createAudioControllers();
      _updateMasterTimeline(preservePosition: true);
    }
  }

  Future<void> _generateVideoTracks({
    required List<File> processedFile,
    required List<File> originalFile,
    Map<String, bool>? preserveMuteStates,
  }) async {
    // Save old track info before clearing
    final oldTrackInfos = _videoTracks
        .map((t) => (t.id, t.originalFile.path, t.totalDuration, t.startTime))
        .toList();
    final oldMuteStates = preserveMuteStates ?? <String, bool>{};
    _videoTracks.clear();
    setVideoTrackIndex(-1); // No auto-selection of first track
    int currentTime = 0;

    // First pass: Create all tracks and try to match with old tracks
    for (int i = 0; i < processedFile.length; i++) {
      final totalDuration = await getMediaDuration(processedFile[i].path);
      bool hasOriginalAudio = false;
      try {
        final probeSession = await FFmpegKit.execute(
          '-hide_banner -i "${originalFile[i].path}"',
        );
        final probeLogs = await probeSession.getOutput();
        hasOriginalAudio = probeLogs?.contains('Audio:') == true;
      } catch (e) {
        hasOriginalAudio = false;
      }

      // Try to find matching old track based on file path and position
      String newId = const Uuid().v4(); // Initialize with a new ID by default
      bool foundMatch = false;

      // First try to match by index if paths match
      if (i < oldTrackInfos.length &&
          oldTrackInfos[i].$2 == originalFile[i].path) {
        newId = oldTrackInfos[i].$1;
        foundMatch = true;
      } else {
        // If no match by index, try to find a match by file path and approximate position
        for (final oldTrack in oldTrackInfos) {
          if (oldTrack.$2 == originalFile[i].path &&
              (oldTrack.$4 - currentTime).abs() < totalDuration) {
            newId = oldTrack.$1;
            foundMatch = true;
            break;
          }
        }
      }

      // Check if this is an image-based video (based on original file)
      // Images are converted to .mp4, so check originalFile to detect image source
      final isImageBased = _isImageFile(originalFile[i].path);

      final track = VideoTrackModel(
        id: newId,
        originalFile: originalFile[i],
        processedFile: processedFile[i],
        startTime: currentTime,
        endTime: currentTime + totalDuration,
        totalDuration: totalDuration,
        hasOriginalAudio: hasOriginalAudio,
        isImageBased: isImageBased,
      );
      _videoTracks.add(track);

      // Create individual video controller for this track
      print('🎥 Creating video controller for track ${track.id}');
      print(
          '  Processing file: ${track.processedFile.path} (original: ${track.originalFile.path})');
      try {
        final controller = VideoEditorController.file(track.processedFile);
        await controller.initialize();
        _videoControllers[track.id] = controller;
        print('  ✅ Controller initialized successfully');
        print('  Video size: ${controller.video.value.size}');
      } catch (e) {
        print('  ❌ Failed to initialize controller: $e');
      }

      // Initialize canvas properties for the new track using real canvas size
      print(
          '🎨 Initializing canvas properties for track in _generateVideoTracks: ${track.id}');
      print('   Current canvas size: $_canvasSize');

      // Use actual canvas size if available, otherwise use reasonable fallback
      Size workingCanvasSize = _canvasSize;
      if (_canvasSize.width <= 0 ||
          _canvasSize.height <= 0 ||
          !_canvasSize.width.isFinite ||
          !_canvasSize.height.isFinite) {
        workingCanvasSize =
            const Size(400, 300); // Better fallback than 300x300
        print('   Canvas size invalid, using fallback: $workingCanvasSize');
      } else {
        print('   Using actual canvas size: $workingCanvasSize');
      }

      // Wait a bit for video controller to initialize
      await Future.delayed(const Duration(milliseconds: 100));

      final autoSize = _calculateAutoSize(track, workingCanvasSize);
      final autoPosition = _calculateAutoPosition(i, workingCanvasSize);

      print('   Calculated size: $autoSize');
      print('   Calculated position: $autoPosition');

      // Update the track with proper canvas properties
      _videoTracks[i] = track.copyWith(
        canvasSize: autoSize,
        canvasPosition: autoPosition,
        canvasScale: 1.0,
        canvasRotation: 0,
        canvasCropModel: null, // No crop by default
        canvasOpacity: 1.0,
      );

      print('✅ Canvas properties updated for track: ${_videoTracks[i].id}');
      print('   Updated canvas size: ${_videoTracks[i].canvasSize}');
      print('   Updated canvas position: ${_videoTracks[i].canvasPosition}');

      // Preserve mute state if we found a match, otherwise use default (unmuted)
      if (foundMatch && (oldMuteStates[track.id] ?? false)) {
        _masterTimelineController
            .toggleVideoMute(track.id); // Set to muted if previously muted
      }

      currentTime += totalDuration;
    }

    // Mute states are now managed by master timeline controller

    // Debug print for duplicate IDs
    final idSet = <String>{};
    for (final t in _videoTracks) {
      if (idSet.contains(t.id)) {
        print('DUPLICATE ID FOUND: ${t.id}');
      }
      idSet.add(t.id);
    }
    print('All video track IDs: ${_videoTracks.map((t) => t.id).toList()}');

    // Trigger UI update after all tracks are initialized
    notifyListeners();

    // Initialize master timeline controller with tracks
    _updateMasterTimeline();

    // Connect disposal callback for aggressive buffer management
    _masterTimelineController.onDisposeUnusedControllers = (keepIds) {
      disposeUnusedVideoControllers(keepIds);
    };

    // Set up recreation callback
    _masterTimelineController.onRecreateController = (trackId) async {
      print('🔄 Recreation requested for $trackId');
      await recreateControllerForTrack(trackId);
    };

    // Set up callbacks
    _masterTimelineController.onPositionChanged = () {
      notifyListeners();
    };
    _masterTimelineController.onPlayStateChanged = () {
      _isPlaying = _masterTimelineController.isPlaying;
      notifyListeners();
    };

    // Don't initialize multi-video canvas - use sequential playback instead
    print('🎯 Sequential playback setup for ${_videoTracks.length} video(s)');
    setUseMultiVideoCanvas(false); // Disable multi-video canvas
  }

  // Add a video track sequentially (stacking)
  Future<void> addVideoTrack(
    File originalFile,
    File processedFile,
    int totalDuration,
  ) async {
    int startTime = _videoTracks.isNotEmpty ? _videoTracks.last.endTime : 0;
    int endTime = startTime + totalDuration;

    // Check if this is an image-based video (based on original file)
    // Images are converted to .mp4, so check originalFile to detect image source
    final isImageBased = _isImageFile(originalFile.path);

    // Check for audio in the original file using the same method as initial loading
    bool hasOriginalAudio = false;
    try {
      final probeSession = await FFmpegKit.execute(
        '-hide_banner -i "${originalFile.path}"',
      );
      final probeLogs = await probeSession.getOutput();
      hasOriginalAudio = probeLogs?.contains('Audio:') == true;
      print(
          '🎵 addVideoTrack audio detection: ${originalFile.path} -> hasAudio: $hasOriginalAudio');
    } catch (e) {
      hasOriginalAudio = false;
      print(
          '❌ addVideoTrack audio detection failed for ${originalFile.path}: $e');
    }

    final track = VideoTrackModel(
      originalFile: originalFile,
      processedFile: processedFile,
      startTime: startTime,
      endTime: endTime,
      totalDuration: totalDuration,
      hasOriginalAudio: hasOriginalAudio,
      isImageBased: isImageBased,
    );
    _videoTracks.add(track);
    _videoDuration = _videoTracks.fold(0.0, (sum, t) {
      final duration = t.isImageBased && t.customDuration != null
          ? t.customDuration!
          : t.totalDuration.toDouble();
      return sum + duration;
    });

    // Always initialize video for first video
    if (_videoTracks.length == 1) {
      await initializeVideo(processedFile.path);
    }

    // Create individual video controller for this track (missing from original method)
    print('🎥 Creating video controller for track ${track.id}');
    print(
        '  Processing file: ${track.processedFile.path} (original: ${track.originalFile.path})');
    try {
      final controller = VideoEditorController.file(track.processedFile);
      await controller.initialize();
      _videoControllers[track.id] = controller;
      print('  ✅ Controller initialized successfully');
      print('  Video size: ${controller.video.value.size}');
    } catch (e) {
      print('  ❌ Failed to initialize controller: $e');
    }

    // Initialize canvas properties for the new track using real canvas size
    print(
        '🎨 Initializing canvas properties for track in addVideoTrack: ${track.id}');
    print('   Current canvas size: $_canvasSize');

    // Use dynamic canvas size that fits optimally in the preview container
    Size workingCanvasSize = _canvasSize.isEmpty
        ? _selectedCanvasRatio.exportSize
        : // Fallback to export size during initialization
        _selectedCanvasRatio.getOptimalCanvasSize(_canvasSize);
    print(
        '   Using dynamic canvas size: $workingCanvasSize (container: $_canvasSize)');

    // Controller is now properly initialized above, no need to wait

    final autoSize = _calculateAutoSize(track, workingCanvasSize);
    final autoPosition =
        _calculateAutoPosition(_videoTracks.length - 1, workingCanvasSize);

    print('   Calculated size: $autoSize');
    print('   Calculated position: $autoPosition');

    // Update the track with proper canvas properties
    final index = _videoTracks.length - 1;
    _videoTracks[index] = track.copyWith(
      canvasSize: autoSize,
      canvasPosition: autoPosition,
      canvasScale: 1.0,
      canvasRotation: 0,
      canvasCropModel: null, // No crop by default
      canvasOpacity: 1.0,
    );

    print('✅ Canvas properties updated for track: ${_videoTracks[index].id}');
    print('   Updated canvas size: ${_videoTracks[index].canvasSize}');
    print('   Updated canvas position: ${_videoTracks[index].canvasPosition}');

    // Update master timeline controller with new tracks (preserve position)
    _updateMasterTimeline(preservePosition: true);

    // Trigger UI update
    notifyListeners();

    // Connect disposal callback for aggressive buffer management
    _masterTimelineController.onDisposeUnusedControllers = (keepIds) {
      disposeUnusedVideoControllers(keepIds);
    };

    // Set up recreation callback
    _masterTimelineController.onRecreateController = (trackId) async {
      print('🔄 Recreation requested for $trackId');
      await recreateControllerForTrack(trackId);
    };

    // Use sequential playback instead of canvas for multiple videos
    print('🎯 Sequential playback for ${_videoTracks.length} video(s)');
    setUseMultiVideoCanvas(false); // Disable multi-video canvas

    notifyListeners();
  }

  /// Apply video trimming to timeline - updates the selected video track and adjusts subsequent tracks
  void _applyVideoTrimToTimeline(double trimStart, double trimEnd) {
    if (_selectedVideoTrackIndex < 0 ||
        _selectedVideoTrackIndex >= _videoTracks.length) {
      return;
    }

    final selectedTrack = _videoTracks[_selectedVideoTrackIndex];
    final originalDuration = selectedTrack.totalDuration.toDouble();

    // Calculate the new duration after trimming
    final effectiveEnd = trimEnd > 0 ? trimEnd : originalDuration;
    final newDuration = effectiveEnd - trimStart;
    final durationChange = newDuration - originalDuration;

    print('🎬 Applying video trim to track ${selectedTrack.id}:');
    print('   Original duration: ${originalDuration}s');
    print('   Trim range: ${trimStart}s to ${effectiveEnd}s');
    print('   New duration: ${newDuration}s');
    print('   Duration change: ${durationChange}s');

    // Update the selected video track with trim values and new duration
    final trimmedTrack = selectedTrack.copyWith(
      videoTrimStart: trimStart,
      videoTrimEnd: effectiveEnd,
      totalDuration: newDuration.round(),
      lastModified: DateTime.now(),
    );

    _videoTracks[_selectedVideoTrackIndex] = trimmedTrack;

    // Adjust subsequent audio and text tracks
    _adjustTracksAfterVideoTrim(selectedTrack, durationChange);

    // Recalculate total timeline duration
    _updateTimelineDuration();
  }

  /// Adjust audio and text tracks after video trimming
  void _adjustTracksAfterVideoTrim(
      VideoTrackModel originalTrack, double durationChange) {
    if (durationChange == 0)
      return; // No adjustment needed if duration didn't change

    final newDuration = originalTrack.totalDuration + durationChange;
    final originalEndTime = originalTrack.endTime.toDouble();
    final newEndTime = originalTrack.startTime.toDouble() + newDuration;

    print('🎵 Adjusting tracks after video trim:');
    print(
        '   Original track: ${originalTrack.id} [${originalTrack.startTime}s - ${originalEndTime}s] (${originalTrack.totalDuration}s)');
    print(
        '   New duration: ${newDuration}s, Duration change: ${durationChange}s');
    print('   New end time: ${newEndTime}s (was ${originalEndTime}s)');
    print('   Audio tracks to process: ${_audioTracks.length}');
    print('   Text tracks to process: ${_textTracks.length}');

    // --- AUDIO TRACKS ---
    List<AudioTrackModel> newAudioTracks = [];
    for (final audio in _audioTracks) {
      print(
          '   🎵 Processing audio track [${audio.trimStartTime}s - ${audio.trimEndTime}s]');

      // Only adjust tracks that start AFTER the original video segment's END
      // These tracks need to be shifted left/right based on the duration change
      if (audio.trimStartTime >= originalEndTime) {
        final newStartTime =
            (audio.trimStartTime + durationChange).clamp(0, double.infinity);
        final newEndTime =
            (audio.trimEndTime + durationChange).clamp(0, double.infinity);

        print(
            '      → Track starts after trimmed video segment, shifting by ${durationChange}s');
        print('      → New position: [${newStartTime}s - ${newEndTime}s]');

        newAudioTracks.add(audio.copyWith(
          trimStartTime: newStartTime.toDouble(),
          trimEndTime: newEndTime.toDouble(),
          updateTimestamp: true,
        ));
      } else {
        // Tracks that start before the video segment end remain unchanged
        print(
            '      → Track starts before/within video segment, keeping unchanged');
        newAudioTracks.add(audio);
      }
    }
    _audioTracks = newAudioTracks;

    // --- TEXT TRACKS ---
    List<TextTrackModel> newTextTracks = [];
    for (final text in _textTracks) {
      print(
          '   📝 Processing text track [${text.trimStartTime}s - ${text.trimEndTime}s]');

      // Only adjust tracks that start AFTER the original video segment's END
      if (text.trimStartTime >= originalEndTime) {
        final newStartTime =
            (text.trimStartTime + durationChange).clamp(0, double.infinity);
        final newEndTime =
            (text.trimEndTime + durationChange).clamp(0, double.infinity);

        print(
            '      → Track starts after trimmed video segment, shifting by ${durationChange}s');
        print('      → New position: [${newStartTime}s - ${newEndTime}s]');

        newTextTracks.add(text.copyWith(
          startTime: newStartTime.toDouble(),
          endTime: newEndTime.toDouble(),
          updateTimestamp: true,
        ));
      } else {
        // Tracks that start before the video segment end remain unchanged
        print(
            '      → Track starts before/within video segment, keeping unchanged');
        newTextTracks.add(text);
      }
    }
    _textTracks = newTextTracks;

    print('   ✅ Track adjustment completed');
  }

  /// Update timeline duration after video track changes
  void _updateTimelineDuration() {
    // Update video track start/end times for sequential playback
    double currentTime = 0.0;
    for (int i = 0; i < _videoTracks.length; i++) {
      final track = _videoTracks[i];
      final newStartTime = currentTime;
      final newEndTime = newStartTime + track.totalDuration;

      if (track.startTime != newStartTime || track.endTime != newEndTime) {
        _videoTracks[i] = track.copyWith(
          startTime: newStartTime.toInt(),
          endTime: newEndTime.toInt(),
        );
      }

      currentTime = newEndTime;
    }

    // Update master timeline controller
    _masterTimelineController.initialize(
      tracks: _videoTracks,
      controllers: Map.fromEntries(_videoTracks
          .where((track) => _videoControllers.containsKey(track.id))
          .map((track) => MapEntry(track.id, _videoControllers[track.id]!))),
      audioTracks: _audioTracks,
      audioControllers: _audioControllers,
    );
  }

  // Remove a video track and recalculate start/end times, preserving IDs
  Future<void> removeVideoTrack(int index) async {
    if (index < 0 || index >= _videoTracks.length) return;
    final deletedTrack = _videoTracks[index];

    // Remove the track at the given index
    _videoTracks.removeAt(index);

    // Mute states are now managed by master timeline controller

    // --- AUDIO TRACKS ---
    List<AudioTrackModel> newAudioTracks = [];
    for (final audio in _audioTracks) {
      // Entirely before deleted segment: keep as is
      if (audio.trimEndTime <= deletedTrack.startTime) {
        print(
            'Audio track [${audio.trimStartTime}, ${audio.trimEndTime}] kept (before deleted segment)');
        newAudioTracks.add(audio);
        continue;
      }
      // Fully within deleted segment: remove
      if (audio.trimStartTime >= deletedTrack.startTime &&
          audio.trimEndTime <= deletedTrack.endTime) {
        print(
            'Audio track [${audio.trimStartTime}, ${audio.trimEndTime}] removed (fully within deleted segment)');
        continue;
      }
      // Spans before and after deleted segment: split into two
      if (audio.trimStartTime < deletedTrack.startTime &&
          audio.trimEndTime > deletedTrack.endTime) {
        print(
            'Audio track [${audio.trimStartTime}, ${audio.trimEndTime}] split (spans deleted segment)');
        newAudioTracks.add(audio.copyWith(
          id: const Uuid().v4(),
          trimStartTime: audio.trimStartTime,
          trimEndTime: deletedTrack.startTime.toDouble(),
        ));
        newAudioTracks.add(audio.copyWith(
          id: const Uuid().v4(),
          trimStartTime:
              (deletedTrack.endTime - deletedTrack.totalDuration).toDouble(),
          trimEndTime:
              (audio.trimEndTime - deletedTrack.totalDuration).toDouble(),
        ));
        continue;
      }
      // Overlaps start of deleted segment
      if (audio.trimStartTime < deletedTrack.startTime &&
          audio.trimEndTime > deletedTrack.startTime &&
          audio.trimEndTime <= deletedTrack.endTime) {
        print(
            'Audio track [${audio.trimStartTime}, ${audio.trimEndTime}] trimmed (overlaps start of deleted segment)');
        newAudioTracks.add(audio.copyWith(
          trimStartTime: audio.trimStartTime,
          trimEndTime: deletedTrack.startTime.toDouble(),
        ));
        continue;
      }
      // Overlaps end of deleted segment
      if (audio.trimStartTime >= deletedTrack.startTime &&
          audio.trimStartTime < deletedTrack.endTime &&
          audio.trimEndTime > deletedTrack.endTime) {
        print(
            'Audio track [${audio.trimStartTime}, ${audio.trimEndTime}] trimmed (overlaps end of deleted segment)');
        newAudioTracks.add(audio.copyWith(
          trimStartTime:
              (deletedTrack.endTime - deletedTrack.totalDuration).toDouble(),
          trimEndTime:
              (audio.trimEndTime - deletedTrack.totalDuration).toDouble(),
        ));
        continue;
      }
      // Starts after deleted segment: shift
      if (audio.trimStartTime >= deletedTrack.endTime) {
        print(
            'Audio track [${audio.trimStartTime}, ${audio.trimEndTime}] shifted (after deleted segment)');
        newAudioTracks.add(audio.copyWith(
          trimStartTime:
              (audio.trimStartTime - deletedTrack.totalDuration).toDouble(),
          trimEndTime:
              (audio.trimEndTime - deletedTrack.totalDuration).toDouble(),
        ));
        continue;
      }
      // Otherwise, keep as is
      print(
          'Audio track [${audio.trimStartTime}, ${audio.trimEndTime}] kept (default case)');
      newAudioTracks.add(audio);
    }
    _audioTracks = newAudioTracks;

    // --- TEXT TRACKS ---
    List<TextTrackModel> newTextTracks = [];
    for (final text in _textTracks) {
      // Entirely before deleted segment: keep as is
      if (text.trimEndTime <= deletedTrack.startTime) {
        print(
            'Text track [${text.trimStartTime}, ${text.trimEndTime}] kept (before deleted segment)');
        newTextTracks.add(text);
        continue;
      }
      // Fully within deleted segment: remove
      if (text.trimStartTime >= deletedTrack.startTime &&
          text.trimEndTime <= deletedTrack.endTime) {
        print(
            'Text track [${text.trimStartTime}, ${text.trimEndTime}] removed (fully within deleted segment)');
        continue;
      }
      // Spans before and after deleted segment: split into two
      if (text.trimStartTime < deletedTrack.startTime &&
          text.trimEndTime > deletedTrack.endTime) {
        print(
            'Text track [${text.trimStartTime}, ${text.trimEndTime}] split (spans deleted segment)');
        newTextTracks.add(text.copyWith(
          id: const Uuid().v4(),
          startTime: text.trimStartTime,
          endTime: deletedTrack.startTime.toDouble(),
        ));
        newTextTracks.add(text.copyWith(
          id: const Uuid().v4(),
          startTime:
              (deletedTrack.endTime - deletedTrack.totalDuration).toDouble(),
          endTime: (text.trimEndTime - deletedTrack.totalDuration).toDouble(),
        ));
        continue;
      }
      // Overlaps start of deleted segment
      if (text.trimStartTime < deletedTrack.startTime &&
          text.trimEndTime > deletedTrack.startTime &&
          text.trimEndTime <= deletedTrack.endTime) {
        print(
            'Text track [${text.trimStartTime}, ${text.trimEndTime}] trimmed (overlaps start of deleted segment)');
        newTextTracks.add(text.copyWith(
          startTime: text.trimStartTime,
          endTime: deletedTrack.startTime.toDouble(),
        ));
        continue;
      }
      // Overlaps end of deleted segment
      if (text.trimStartTime >= deletedTrack.startTime &&
          text.trimStartTime < deletedTrack.endTime &&
          text.trimEndTime > deletedTrack.endTime) {
        print(
            'Text track [${text.trimStartTime}, ${text.trimEndTime}] trimmed (overlaps end of deleted segment)');
        newTextTracks.add(text.copyWith(
          startTime:
              (deletedTrack.endTime - deletedTrack.totalDuration).toDouble(),
          endTime: (text.trimEndTime - deletedTrack.totalDuration).toDouble(),
        ));
        continue;
      }
      // Starts after deleted segment: shift
      if (text.trimStartTime >= deletedTrack.endTime) {
        print(
            'Text track [${text.trimStartTime}, ${text.trimEndTime}] shifted (after deleted segment)');
        newTextTracks.add(text.copyWith(
          startTime:
              (text.trimStartTime - deletedTrack.totalDuration).toDouble(),
          endTime: (text.trimEndTime - deletedTrack.totalDuration).toDouble(),
        ));
        continue;
      }
      // Otherwise, keep as is
      print(
          'Text track [${text.trimStartTime}, ${text.trimEndTime}] kept (default case)');
      newTextTracks.add(text);
    }
    _textTracks = newTextTracks;

    // Recalculate start/end times for all tracks (IDs are preserved)
    int currentTime = 0;
    for (var i = 0; i < _videoTracks.length; i++) {
      final t = _videoTracks[i];
      _videoTracks[i] = t.copyWith(
        startTime: currentTime,
        endTime: currentTime + t.totalDuration,
        id: t.id, // Explicitly preserve ID
      );
      currentTime += t.totalDuration;
    }
    _videoDuration = _videoTracks.fold(0.0, (sum, t) {
      final duration = t.isImageBased && t.customDuration != null
          ? t.customDuration!
          : t.totalDuration.toDouble();
      return sum + duration;
    });

    if (_videoTracks.isEmpty) {
      _videoEditorController?.dispose();
      _videoEditorController = null;
      _videoDuration = 0.0;
      // Clear master timeline controller
      _updateMasterTimeline();

      // Connect disposal callback for aggressive buffer management
      _masterTimelineController.onDisposeUnusedControllers = (keepIds) {
        disposeUnusedVideoControllers(keepIds);
      };

      // Set up recreation callback
      _masterTimelineController.onRecreateController = (trackId) async {
        print('🔄 Recreation requested for $trackId');
        await recreateControllerForTrack(trackId);
      };

      // Optionally, set a flag: noVideo = true;
      notifyListeners();
      return;
    }

    // Update master timeline controller with updated tracks (preserve position)
    _updateMasterTimeline(preservePosition: true);

    // Connect disposal callback for aggressive buffer management
    _masterTimelineController.onDisposeUnusedControllers = (keepIds) {
      disposeUnusedVideoControllers(keepIds);
    };

    // Set up recreation callback
    _masterTimelineController.onRecreateController = (trackId) async {
      print('🔄 Recreation requested for $trackId');
      await recreateControllerForTrack(trackId);
    };

    // Update the preview video to reflect the new track list
    await _updatePreviewVideo();
  }

  // ===== REORDER MODE METHODS =====

  /// Enter reorder mode
  void enterReorderMode(int trackIndex, {double? touchPositionX}) {
    // Don't enter reorder mode if there's only one track
    if (_videoTracks.length <= 1) {
      print('⚠️ Reorder mode requires at least 2 tracks');
      return;
    }

    // ✅ Don't enter reorder mode if currently editing a track
    if (_isEditingTrack) {
      print('⚠️ Cannot enter reorder mode while editing track');
      print('   Currently editing: $_editingTrackType');
      return;
    }

    _isReorderMode = true;
    _reorderingTrackIndex = trackIndex;
    _reorderTouchPositionX = touchPositionX; // Store touch position

    // Pause playback when entering reorder mode
    if (_masterTimelineController.isPlaying) {
      _masterTimelineController.pause();
    }

    print('🎯 Entered reorder mode at touch position: $touchPositionX');
    notifyListeners();
  }

  /// Exit reorder mode
  void exitReorderMode() {
    _isReorderMode = false;
    _reorderingTrackIndex = null;
    _reorderTouchPositionX = null; // Clear touch position
    notifyListeners();
  }

  /// Reorder video tracks
  void reorderVideoTracks(int oldIndex, int newIndex) {
    // ✅ ReorderableRow from reorderables package already provides corrected indices
    // Unlike Flutter's ReorderableListView, no adjustment needed
    // Applying adjustment would cause double-correction and off-by-one errors

    print('📋 Reorder operation:');
    print('   oldIndex: $oldIndex, newIndex: $newIndex (no adjustment)');
    print('   Track being moved: ${_videoTracks[oldIndex].id}');

    final track = _videoTracks.removeAt(oldIndex);
    _videoTracks.insert(newIndex, track);

    print('   ✅ Track now at position: $newIndex');
    print(
        '   New order: ${_videoTracks.map((t) => _videoTracks.indexOf(t)).toList()}');

    // Recalculate start/end times for sequential playback
    _recalculateVideoTrackTimes();

    // Update reordering index
    _reorderingTrackIndex = newIndex;

    notifyListeners();
  }

  /// Recalculate sequential start/end times for video tracks
  void _recalculateVideoTrackTimes() {
    double currentTime = 0.0;
    for (var i = 0; i < _videoTracks.length; i++) {
      final track = _videoTracks[i];
      // For image-based tracks with customDuration, use that for accurate positioning
      final effectiveDuration =
          track.isImageBased && track.customDuration != null
              ? track.customDuration!
              : track.totalDuration.toDouble();

      _videoTracks[i] = track.copyWith(
        startTime: currentTime.round(),
        endTime: (currentTime + effectiveDuration).round(),
        id: track.id, // Preserve ID
      );
      currentTime += effectiveDuration;
    }

    _videoDuration = _videoTracks.fold(0.0, (sum, t) {
      final duration = t.isImageBased && t.customDuration != null
          ? t.customDuration!
          : t.totalDuration.toDouble();
      return sum + duration;
    });
  }

  /// Finalize reorder - reinitialize master timeline
  void finalizeReorder() {
    // Reinitialize master timeline with new track order
    _updateMasterTimeline();

    // Connect disposal callback
    _masterTimelineController.onDisposeUnusedControllers = (keepIds) {
      disposeUnusedVideoControllers(keepIds);
    };

    // Set up recreation callback
    _masterTimelineController.onRecreateController = (trackId) async {
      print('🔄 Recreation requested for $trackId');
      await recreateControllerForTrack(trackId);
    };

    notifyListeners();
  }

  // Helper to update the preview video after track changes
  Future<void> _updatePreviewVideo() async {
    // Use combineMediaFiles to combine the current _videoTracks into a new preview file
    final processedFiles = _videoTracks.map((t) => t.processedFile).toList();
    final recSize = recommendedAspectRatio ?? const Size(1920, 1080);
    final (
      File? combined,
      List<(File, File)>? processedPairs,
    ) = await EditorVideoController.combineMediaFiles(
      processedFiles,
      outputHeight: recSize.height.toInt(),
      outputWidth: recSize.width.toInt(),
    );
    if (combined != null) {
      await initializeVideo(combined.path);
      await initializeOrResetControllers();

      // For sequential playback, use sum of individual video tracks instead of combined video duration
      _videoDuration = _videoTracks.fold(0.0, (sum, t) {
        final duration = t.isImageBased && t.customDuration != null
            ? t.customDuration!
            : t.totalDuration.toDouble();
        return sum + duration;
      });
      print('🎯 Sequential playback total duration: ${_videoDuration}s');

      videoEditorController?.video.removeListener(listenVideoPosition);
      videoEditorController?.video.addListener(listenVideoPosition);
    }
    notifyListeners();
  }

  Future<void> pickAudioFile(BuildContext context) async {
    // Pre-check: Do we have available space in any lane?
    final availableSpace = getAvailableAudioSpaceAtCurrentPosition();

    if (availableSpace == null) {
      // No space available in any lane
      showSnackBar(
        context,
        "Cannot add audio: All lanes occupied or less than 1s available. "
        "Move playhead or remove existing tracks.",
      );
      return;
    }

    // Show info about available space
    final currentPosition = _masterTimelineController.currentTimelinePosition;
    print(
        '📊 Available audio space: ${availableSpace.duration.toStringAsFixed(1)}s in Lane ${availableSpace.laneIndex} at ${currentPosition.toStringAsFixed(1)}s');

    // Now open file picker
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: ['mp3'],
    );
    if (result?.files.single.path == null) return;

    File pickedFile = File(result!.files.single.path!);
    double pickFileAudioDuration = (await getMediaDuration(
      pickedFile.path,
    ))
        .toDouble();

    print(
        '🎵 Opening AudioTrimmer with max ${availableSpace.duration.toStringAsFixed(1)}s available');

    // Open AudioTrimmer with available duration
    final trimmedFile = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (context) {
          return AudioTrimmer(
            audioFile: pickedFile,
            audioDuration: pickFileAudioDuration,
            remainAudioDuration:
                availableSpace.duration, // Pass available space in best lane
          );
        },
      ),
    );

    // If user completed trimming, add the audio track
    if (trimmedFile != null) {
      final finalAudioDuration = await getMediaDuration(trimmedFile.path);
      if (finalAudioDuration <= 0) {
        showSnackBar(context, "Failed to process audio.");
        return;
      }

      // Add audio track with the pre-checked lane and available duration
      await addAudioTrack(
        context,
        trimmedFile,
        finalAudioDuration.toDouble(),
        availableSpace.duration, // Max available in that lane
        availableSpace.laneIndex, // Use the pre-checked lane
      );
    }
  }

  Future<void> addAudioTrack(
    BuildContext context,
    File audioFile,
    double totalDuration,
    double maxAvailableDuration,
    int targetLane,
  ) async {
    final startTime = _masterTimelineController.currentTimelinePosition;

    // Calculate actual duration (smaller of total or available space)
    final actualDuration = min(totalDuration, maxAvailableDuration);
    final endTime = startTime + actualDuration;

    final audioTrack = AudioTrackModel(
      audioFile: audioFile,
      trimStartTime: startTime,
      trimEndTime: endTime,
      totalDuration: totalDuration, // Keep original for reference
      laneIndex: targetLane,
    );

    _audioTracks.add(audioTrack);

    // Provide user feedback
    String message = "Audio added to Lane ${targetLane + 1}";
    if (actualDuration < totalDuration) {
      final trimmedAmount = totalDuration - actualDuration;
      message +=
          " (auto-trimmed ${trimmedAmount.toStringAsFixed(1)}s to fit available space)";
    }

    print(
        '✅ $message at ${startTime.toStringAsFixed(1)}s-${endTime.toStringAsFixed(1)}s');
    // Snackbar removed - user doesn't need notification for every successful addition

    // Create audio controllers and update master timeline
    await _createAudioControllers();
    _updateMasterTimeline(preservePosition: true);

    // Show audio in timeline after first track is added
    _showAudioInTimeline = true;

    notifyListeners();
  }

  Future<void> removeAudioTrack(int index) async {
    if (index >= 0 && index < _audioTracks.length) {
      final removedTrack = _audioTracks[index];
      print(
          '🗑️ Removing audio track at index $index (Lane ${removedTrack.laneIndex})');

      _audioTracks.removeAt(index);

      // CRITICAL: Compact lanes after deletion to remove gaps
      _compactAudioLanes();

      // Dispose the specific audio controller
      final controller = _audioControllers[removedTrack.id];
      if (controller != null) {
        controller.dispose();
        _audioControllers.remove(removedTrack.id);
      }

      // Update master timeline (preserve position)
      _updateMasterTimeline(preservePosition: true);

      print('✅ Audio track removed. Remaining tracks: ${_audioTracks.length}');
    }
    notifyListeners();
  }

  Future<void> updateAudioTrack(
    int index,
    double startTime,
    double endTime,
  ) async {
    if (index >= 0 && index < _audioTracks.length) {
      _audioTracks[index] = _audioTracks[index].copyWith(
        trimStartTime: startTime,
        trimEndTime: endTime,
      );

      // Update master timeline with new audio track data (preserve position)
      _updateMasterTimeline(preservePosition: true);
    }
    notifyListeners();
  }

  // Video track update method for UI trim operations (debounced)
  Future<void> updateVideoTrack(
    int index,
    double trimStart,
    double trimEnd,
  ) async {
    if (index < 0 || index >= _videoTracks.length) return;

    print("=== Updating video track trim values ===");
    print("Track index: $index");
    print("Trim start: $trimStart, Trim end: $trimEnd");

    // Preserve current timeline position before updating
    final currentPosition = _masterTimelineController.currentTimelinePosition;
    final track = _videoTracks[index];

    // Calculate relative position within the current track if position is within this track
    double? relativePosition;
    if (currentPosition >= track.startTime.toDouble() &&
        currentPosition <= track.endTime.toDouble()) {
      final positionInTrack = currentPosition - track.startTime.toDouble();
      final trackCurrentDuration = track.videoTrimEnd - track.videoTrimStart;
      if (trackCurrentDuration > 0) {
        relativePosition = positionInTrack / trackCurrentDuration;
        print(
            "Current position within track: $positionInTrack / $trackCurrentDuration = $relativePosition");
      }
    }

    // Update the track with new trim values
    final trimmedDuration = trimEnd - trimStart;

    final updatedTrack = track.copyWith(
      videoTrimStart: trimStart,
      videoTrimEnd: trimEnd,
      totalDuration:
          trimmedDuration.round(), // Use rounded double to int for consistency
      // Don't update lastModified for trim operations - preserve original to avoid thumbnail regeneration
    );

    _videoTracks[index] = updatedTrack;

    // Recalculate timeline positions
    await _recalculateVideoTrackPositions();

    // Update master timeline controller
    final controllers = <String, VideoEditorController>{};
    for (final track in _videoTracks) {
      final controller = _videoControllers[track.id];
      if (controller != null) {
        controllers[track.id] = controller;
      }
    }

    _updateMasterTimeline(preservePosition: true);

    // Restore timeline position proportionally if it was within the trimmed track
    if (relativePosition != null) {
      final updatedTrackInfo = _videoTracks[index];
      final newTrackDuration = updatedTrackInfo.totalDuration.toDouble();
      final newPositionInTrack = relativePosition * newTrackDuration;
      final newTimelinePosition =
          updatedTrackInfo.startTime.toDouble() + newPositionInTrack;

      print(
          "Restoring timeline position: ${newTimelinePosition.toStringAsFixed(2)}s");
      _masterTimelineController.seekToTime(newTimelinePosition);
    } else {
      // If position wasn't in the trimmed track, keep current position if still valid
      final totalDuration = _masterTimelineController.totalDuration;
      if (currentPosition <= totalDuration) {
        _masterTimelineController.seekToTime(currentPosition);
      }
    }

    notifyListeners();
  }

  // Update video track timeline position for hold-and-drag repositioning
  void updateVideoTrackPosition(int index, int newStartTime) {
    if (index < 0 || index >= _videoTracks.length) return;

    final track = _videoTracks[index];
    final newEndTime = newStartTime + track.totalDuration;

    // Update the track with new timeline position
    _videoTracks[index] = track.copyWith(
      startTime: newStartTime,
      endTime: newEndTime,
    );

    // Update master timeline controller to reflect the change (preserve position)
    _updateMasterTimeline(preservePosition: true);

    notifyListeners();
  }

  // Update audio track timeline position for hold-and-drag repositioning
  void updateAudioTrackPosition(
      int index, double newStartTime, double newEndTime) {
    if (index < 0 || index >= _audioTracks.length) return;

    final track = _audioTracks[index];
    final trackDuration = newEndTime - newStartTime;
    final laneIndex = track.laneIndex;

    // Get sorted tracks in same lane (excluding current track)
    final tracksInLane =
        getAudioTracksInLane(laneIndex).where((t) => t.id != track.id).toList();

    // Calculate safe boundaries
    double lowerLimit = 0.0;
    double upperLimit = _videoDuration;

    // Find tracks before and after desired position
    for (var otherTrack in tracksInLane) {
      // Track ends before our start - potential lower limit
      if (otherTrack.trimEndTime <= newStartTime) {
        lowerLimit = max(lowerLimit, otherTrack.trimEndTime);
      }
      // Track starts after our end - potential upper limit
      else if (otherTrack.trimStartTime >= newEndTime) {
        upperLimit = min(upperLimit, otherTrack.trimStartTime);
      }
      // Overlapping track detected - need to adjust
      else {
        // Collision detected - clamp to safe position
        if (newStartTime < otherTrack.trimStartTime) {
          // Moving right into collision - stop at left edge
          upperLimit = min(upperLimit, otherTrack.trimStartTime);
        } else {
          // Moving left into collision - stop at right edge
          lowerLimit = max(lowerLimit, otherTrack.trimEndTime);
        }
      }
    }

    // Clamp position to safe boundaries
    final safeStartTime =
        newStartTime.clamp(lowerLimit, upperLimit - trackDuration);
    final safeEndTime = safeStartTime + trackDuration;

    // Update the track with validated position
    _audioTracks[index] = track.copyWith(
      trimStartTime: safeStartTime,
      trimEndTime: safeEndTime,
    );

    // Update master timeline controller to reflect the change (preserve position)
    _updateMasterTimeline(preservePosition: true);

    notifyListeners();
  }

  /// Attempt to switch audio track to different lane with smart placement
  /// Automatically finds nearest available gap if desired position is occupied
  /// Returns true if successful, false if no space available in target lane
  Future<bool> attemptAudioLaneSwitch(
    BuildContext context,
    int trackIndex,
    int fromLane,
    int toLane, {
    bool autoTrim = true,
  }) async {
    if (trackIndex < 0 || trackIndex >= _audioTracks.length) return false;
    if (toLane < 0 || toLane >= maxLanes) return false;
    if (fromLane == toLane) return true; // No change needed

    final track = _audioTracks[trackIndex];
    final trackDuration = track.trimEndTime - track.trimStartTime;
    final currentStartTime = track.trimStartTime;

    print(
        '🎯 Attempting audio lane switch: $fromLane → $toLane at ${currentStartTime.toStringAsFixed(1)}s (${trackDuration.toStringAsFixed(1)}s)');

    // Smart placement: find best position in target lane
    final placement =
        findSmartPlacementInAudioLane(toLane, currentStartTime, trackDuration);

    if (placement == null) {
      // No space at all in target lane
      print('❌ Cannot switch audio to lane $toLane: Lane is fully occupied');
      // Snackbar removed as per user request
      return false;
    }

    // Place track at smart position
    _audioTracks[trackIndex] = track.copyWith(
      trimStartTime: placement.startTime,
      trimEndTime: placement.startTime + placement.duration,
      laneIndex: toLane,
    );

    // Provide feedback only if position or duration changed significantly
    final positionChanged =
        (placement.startTime - currentStartTime).abs() > 0.1;
    final durationChanged = (placement.duration - trackDuration).abs() > 0.1;

    if (positionChanged || durationChanged) {
      String message = "Moved to Audio Lane ${toLane + 1}";

      if (positionChanged) {
        message += " at ${placement.startTime.toStringAsFixed(1)}s";
      }

      if (durationChanged) {
        message += " (trimmed to ${placement.duration.toStringAsFixed(1)}s)";
      }

      // Snackbar removed as per user request
      print('📍 $message');
    } else {
      print('✅ Switched audio track to lane $toLane at same position');
    }

    // CRITICAL: Compact lanes after switch (may have created gap in fromLane)
    _compactAudioLanes();

    // Recreate audio controllers and update master timeline
    await _createAudioControllers();
    _updateMasterTimeline(preservePosition: true);

    notifyListeners();
    return true;
  }

  // Update text track timeline position for hold-and-drag repositioning
  void updateTextTrackTimelinePosition(
      int index, double newStartTime, double newEndTime) {
    if (index < 0 || index >= _textTracks.length) return;

    final track = _textTracks[index];
    final trackDuration = newEndTime - newStartTime;
    final laneIndex = track.laneIndex;

    // Get sorted tracks in same lane (excluding current track)
    final tracksInLane =
        getTextTracksInLane(laneIndex).where((t) => t.id != track.id).toList();

    // Calculate safe boundaries
    double lowerLimit = 0.0;
    double upperLimit = _videoDuration;

    // Find tracks before and after desired position
    for (var otherTrack in tracksInLane) {
      // Track ends before our start - potential lower limit
      if (otherTrack.trimEndTime <= newStartTime) {
        lowerLimit = max(lowerLimit, otherTrack.trimEndTime);
      }
      // Track starts after our end - potential upper limit
      else if (otherTrack.trimStartTime >= newEndTime) {
        upperLimit = min(upperLimit, otherTrack.trimStartTime);
      }
      // Overlapping track detected - need to adjust
      else {
        // Collision detected - clamp to safe position
        if (newStartTime < otherTrack.trimStartTime) {
          // Moving right into collision - stop at left edge
          upperLimit = min(upperLimit, otherTrack.trimStartTime);
        } else {
          // Moving left into collision - stop at right edge
          lowerLimit = max(lowerLimit, otherTrack.trimEndTime);
        }
      }
    }

    // Clamp position to safe boundaries
    final safeStartTime =
        newStartTime.clamp(lowerLimit, upperLimit - trackDuration);
    final safeEndTime = safeStartTime + trackDuration;

    // Update the track with validated position
    _textTracks[index] = track.copyWith(
      startTime: safeStartTime,
      endTime: safeEndTime,
    );

    notifyListeners();
  }

  // Video trim functionality
  Future<void> trimVideoTrack(
    int index,
    double startTime,
    double endTime,
  ) async {
    if (index < 0 || index >= _videoTracks.length) return;

    final track = _videoTracks[index];
    final trimDuration = endTime - startTime;

    print("=== Starting video trim ===");
    print("Track index: $index");
    print("Track ID: ${track.id}");
    print("Original file: ${track.processedFile.path}");
    print(
        "Start time: $startTime, End time: $endTime, Duration: $trimDuration");

    if (trimDuration <= 0) {
      throw Exception("Invalid trim duration: $trimDuration");
    }

    try {
      // Create trimmed video file using FFmpeg
      final trimmedFile = await _createTrimmedVideo(
        track.processedFile,
        startTime,
        endTime,
      );

      if (trimmedFile == null) {
        throw Exception("Failed to create trimmed video file");
      }

      print("Trimmed file created: ${trimmedFile.path}");

      // Update the track with new trim values and file
      final updatedTrack = track.copyWith(
        processedFile: trimmedFile,
        videoTrimStart: startTime,
        videoTrimEnd: endTime,
        totalDuration: trimDuration.toInt(),
        originalDuration: track.originalDuration == 0
            ? track.totalDuration.toDouble()
            : track.originalDuration,
      );

      _videoTracks[index] = updatedTrack;
      print(
          "Track updated: ${updatedTrack.id}, new duration: ${updatedTrack.totalDuration}");

      // Store original timeline positions before recalculation
      final originalSegmentStart = track.startTime.toDouble();
      final originalSegmentEnd = track.endTime.toDouble();
      final originalSegmentDuration = originalSegmentEnd - originalSegmentStart;

      // Recalculate timeline positions for all tracks
      await _recalculateVideoTrackPositions();

      // Get updated track with new timeline positions
      final recalculatedTrack = _videoTracks[index];
      final newSegmentStart = recalculatedTrack.startTime.toDouble();
      final newSegmentEnd = recalculatedTrack.endTime.toDouble();

      // Update preview video to reflect changes
      if (_videoTracks.length == 1) {
        // For single track, directly use the trimmed file
        print("Single track detected, initializing with trimmed file directly");
        await initializeVideo(trimmedFile.path);
        // For sequential playback, use sum of individual video tracks
        _videoDuration = _videoTracks.fold(0.0, (sum, t) {
          final duration = t.isImageBased && t.customDuration != null
              ? t.customDuration!
              : t.totalDuration.toDouble();
          return sum + duration;
        });
        print("Updated video duration after trim: $_videoDuration seconds");
        notifyListeners();
      } else {
        // For multiple tracks, combine them
        print("Multiple tracks detected, combining videos");
        await _updatePreviewVideo();
      }

      // Apply cascade updates to text and audio overlays using correct timeline positions
      final adjustmentMessages = await _cascadeUpdateAfterVideoTrim(
        index,
        originalSegmentStart,
        originalSegmentEnd,
        newSegmentStart,
        newSegmentEnd,
        startTime, // trim start within segment
        endTime, // trim end within segment
      );

      print("=== Video trim completed successfully ===");

      // Force UI update to ensure VideoTrack widgets are rebuilt with new file
      notifyListeners();

      // Add a small delay to ensure the UI has updated before any additional processing
      await Future.delayed(const Duration(milliseconds: 100));

      // Return adjustment messages for user feedback (if needed)
      if (adjustmentMessages.isNotEmpty) {
        print("Overlay adjustments made: ${adjustmentMessages.join(', ')}");
      }
    } catch (e) {
      print("=== Video trim failed: ${e.toString()} ===");
      throw Exception("Failed to trim video: ${e.toString()}");
    }
  }

  Future<File?> _createTrimmedVideo(
    File inputFile,
    double startTime,
    double endTime,
  ) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_trimmed_video.mp4';

      final duration = endTime - startTime;

      // Use re-encoding for accurate trimming instead of stream copy
      // This ensures proper frame accuracy and playback
      final command =
          '-i "${inputFile.path}" -ss $startTime -t $duration -c:v libx264 -c:a aac -preset fast -crf 23 "$outputPath"';

      print("Trimming video with command: $command");

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      final logs = await session.getAllLogsAsString();

      print("FFmpeg trim return code: $returnCode");
      print("FFmpeg trim logs: $logs");

      if (ReturnCode.isSuccess(returnCode) && File(outputPath).existsSync()) {
        final outputFile = File(outputPath);
        final fileSize = await outputFile.length();
        print(
            "Trimmed video created successfully: $outputPath (${fileSize} bytes)");

        // Validate the trimmed video
        final isValid =
            await _validateTrimmedVideo(outputFile, endTime - startTime);
        if (!isValid) {
          print("Trimmed video validation failed");
          return null;
        }

        return outputFile;
      } else {
        print("Failed to create trimmed video. Return code: $returnCode");
        print("Output file exists: ${File(outputPath).existsSync()}");
        return null;
      }
    } catch (e) {
      print("Error creating trimmed video: $e");
      return null;
    }
  }

  Future<void> _recalculateVideoTrackPositions() async {
    double currentTime = 0.0;
    for (var i = 0; i < _videoTracks.length; i++) {
      final track = _videoTracks[i];
      // For image-based tracks with customDuration, use that for accurate positioning
      final effectiveDuration =
          track.isImageBased && track.customDuration != null
              ? track.customDuration!
              : track.totalDuration.toDouble();

      _videoTracks[i] = track.copyWith(
        startTime: currentTime.round(),
        endTime: (currentTime + effectiveDuration).round(),
      );
      currentTime += effectiveDuration;
    }

    _videoDuration = _videoTracks.fold(0.0, (sum, t) {
      final duration = t.isImageBased && t.customDuration != null
          ? t.customDuration!
          : t.totalDuration.toDouble();
      return sum + duration;
    });
  }

  Future<bool> _validateTrimmedVideo(
      File videoFile, double expectedDuration) async {
    try {
      // Use FFprobe to get video information
      final session =
          await FFmpegKit.execute('-i "${videoFile.path}" -hide_banner');
      final logs = await session.getAllLogsAsString() ?? '';

      // Check if video has valid duration
      final durationRegex =
          RegExp(r'Duration: (\d{2}):(\d{2}):(\d{2})\.(\d{2})');
      final match = durationRegex.firstMatch(logs);

      if (match != null) {
        final hours = int.parse(match.group(1)!);
        final minutes = int.parse(match.group(2)!);
        final seconds = int.parse(match.group(3)!);
        final centiseconds = int.parse(match.group(4)!);

        final actualDuration =
            hours * 3600 + minutes * 60 + seconds + centiseconds / 100;
        print(
            "Expected duration: $expectedDuration, Actual duration: $actualDuration");

        // Allow some tolerance (±0.5 seconds)
        final tolerance = 0.5;
        final isValid =
            (actualDuration - expectedDuration).abs() <= tolerance &&
                actualDuration > 0;

        if (!isValid) {
          print(
              "Duration mismatch: expected $expectedDuration, got $actualDuration");
        }

        return isValid;
      } else {
        print("Could not parse video duration from logs");
        return false;
      }
    } catch (e) {
      print("Error validating trimmed video: $e");
      return false;
    }
  }

  // Helper method to check if a file is an image
  bool _isImageFile(String filePath) {
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp'];
    final extension = filePath.toLowerCase().split('.').last;
    return imageExtensions.contains('.$extension');
  }

  // Image video stretch functionality - OPTIMIZED FOR PREVIEW
  // During preview: Updates duration in memory only (no FFmpeg)
  // During export: FFmpeg generates stretched videos automatically (see video_export_manager.dart)
  Future<void> stretchImageVideo(int index, double newDuration) async {
    if (index < 0 || index >= _videoTracks.length) return;

    final track = _videoTracks[index];

    // Only allow stretching for image-based videos
    if (!track.isImageBased) {
      throw Exception("Stretch is only available for image-based videos");
    }

    print("=== Starting image video stretch (preview mode) ===");
    print("Track index: $index");
    print("Track ID: ${track.id}");
    print("Original file: ${track.originalFile.path}");
    print(
        "Current duration: ${track.totalDuration}, New duration: $newDuration");

    if (newDuration <= 0) {
      throw Exception("Invalid stretch duration: $newDuration");
    }

    try {
      // Add to undo stack before making changes
      _addToUndoStack(
        EditOperation(
          EditOperationType.stretch,
          {
            'trackIndex': index,
            'originalDuration': track.totalDuration.toDouble(),
            'originalFile': track.processedFile,
          },
          {
            'trackIndex': index,
            'newDuration': newDuration,
          },
        ),
      );

      // Store original timeline positions for cascade updates
      final originalSegmentStart = track.startTime.toDouble();
      final originalSegmentEnd = track.endTime.toDouble();
      final originalDuration = track.totalDuration.toDouble();

      // PREVIEW OPTIMIZATION: Update duration in memory only (no FFmpeg regeneration)
      // The ImagePainter in media_canvas_renderer.dart will display the cached image
      // for the new duration. Actual video file generation happens during export.
      final updatedTrack = track.copyWith(
        totalDuration: newDuration.toInt(),
        customDuration: newDuration,
        lastModified: DateTime.now(),
      );

      _videoTracks[index] = updatedTrack;
      print(
          "✅ Track duration updated in memory: ${updatedTrack.id}, new duration: ${updatedTrack.totalDuration}s");
      print("   (FFmpeg generation deferred to export)");

      // Recalculate timeline positions for all tracks
      await _recalculateVideoTrackPositions();

      // Get new timeline positions after recalculation
      final newSegmentStart = _videoTracks[index].startTime.toDouble();
      final newSegmentEnd = _videoTracks[index].endTime.toDouble();

      // Apply cascade updates to text and audio overlays
      final adjustmentMessages = await _cascadeUpdateAfterStretch(
        index,
        originalSegmentStart,
        originalSegmentEnd,
        newSegmentStart,
        newSegmentEnd,
        originalDuration,
        newDuration,
      );

      print("=== Image video stretch completed (instant preview) ===");

      // Reinitialize master timeline controller with updated tracks
      // This ensures audio/text timelines recalculate their widths
      _masterTimelineController.initialize(
        tracks: _videoTracks,
        controllers: _videoControllers,
        audioTracks: _audioTracks,
        audioControllers: _audioControllers,
        preservePosition: true,
      );

      // Force UI update
      notifyListeners();

      // Clear stretch progress now that model is updated
      clearStretchProgress();

      // Return adjustment messages for user feedback (if needed)
      if (adjustmentMessages.isNotEmpty) {
        print("Overlay adjustments made: ${adjustmentMessages.join(', ')}");
      }
    } catch (e) {
      print("=== Image video stretch failed: ${e.toString()} ===");
      clearStretchProgress(); // Clear on error too
      throw Exception("Failed to stretch image video: ${e.toString()}");
    }
  }

  Future<File?> _createStretchedImageVideo(
    File originalImageFile,
    double newDuration,
    Size targetSize,
  ) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_stretched_img.mp4';

      // FFmpeg command to create video with new duration and silent audio
      final command = '-loop 1 -t $newDuration -i "${originalImageFile.path}" '
          '-f lavfi -i anullsrc=r=44100:cl=stereo '
          '-vf "scale=${targetSize.width.toInt()}:${targetSize.height.toInt()}:force_original_aspect_ratio=decrease,'
          'pad=${targetSize.width.toInt()}:${targetSize.height.toInt()}:(ow-iw)/2:(oh-ih)/2:color=black" '
          '-c:v h264 -preset medium -crf 23 -pix_fmt yuv420p '
          '-c:a aac -b:a 128k '
          '-shortest '
          '-r 30 "$outputPath"';

      print("Stretch FFmpeg command: $command");

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      final logs = await session.getLogsAsString();

      if (ReturnCode.isSuccess(returnCode) && File(outputPath).existsSync()) {
        final outputFile = File(outputPath);
        final fileSize = await outputFile.length();
        print(
            "Stretched video created successfully: $outputPath (${fileSize} bytes)");

        // Validate the stretched video
        final isValid = await _validateStretchedVideo(outputFile, newDuration);
        if (!isValid) {
          print("Stretched video validation failed");
          return null;
        }

        return outputFile;
      } else {
        print("Failed to create stretched video. Return code: $returnCode");
        print("FFmpeg logs: $logs");
        return null;
      }
    } catch (e) {
      print("Error creating stretched video: $e");
      return null;
    }
  }

  Future<bool> _validateStretchedVideo(
      File videoFile, double expectedDuration) async {
    try {
      // Use FFprobe to get video information
      final session =
          await FFmpegKit.execute('-i "${videoFile.path}" -hide_banner');
      final logs = await session.getAllLogsAsString() ?? '';

      // Check if video has valid duration
      final durationRegex =
          RegExp(r'Duration: (\d{2}):(\d{2}):(\d{2})\.(\d{2})');
      final match = durationRegex.firstMatch(logs);

      if (match != null) {
        final hours = int.parse(match.group(1)!);
        final minutes = int.parse(match.group(2)!);
        final seconds = int.parse(match.group(3)!);
        final centiseconds = int.parse(match.group(4)!);

        final actualDuration =
            hours * 3600 + minutes * 60 + seconds + centiseconds / 100;
        print(
            "Expected duration: $expectedDuration, Actual duration: $actualDuration");

        // Allow some tolerance (±0.5 seconds)
        final tolerance = 0.5;
        final isValid =
            (actualDuration - expectedDuration).abs() <= tolerance &&
                actualDuration > 0;

        if (!isValid) {
          print(
              "Duration validation failed: expected $expectedDuration, got $actualDuration");
        }

        return isValid;
      } else {
        print("Could not parse video duration from logs");
        return false;
      }
    } catch (e) {
      print("Error validating stretched video: $e");
      return false;
    }
  }

  // Cascade update system for handling overlays when video is stretched
  Future<List<String>> _cascadeUpdateAfterStretch(
    int videoTrackIndex,
    double originalSegmentStart,
    double originalSegmentEnd,
    double newSegmentStart,
    double newSegmentEnd,
    double originalDuration,
    double newDuration,
  ) async {
    // Validation: Check video track index
    if (videoTrackIndex < 0 || videoTrackIndex >= _videoTracks.length) {
      print(
          "ERROR: Invalid video track index: $videoTrackIndex (total: ${_videoTracks.length})");
      return [];
    }

    // Validation: Check duration parameters
    if (originalDuration <= 0 || newDuration <= 0) {
      print(
          "ERROR: Invalid duration parameters: original=$originalDuration, new=$newDuration");
      return [];
    }

    final durationChange = newDuration - originalDuration;
    final adjustmentMessages = <String>[];

    print("=== Starting cascade updates after stretch ===");
    print("Video track index: $videoTrackIndex");
    print(
        "Original segment: $originalSegmentStart - $originalSegmentEnd (${originalDuration}s)");
    print("New segment: $newSegmentStart - $newSegmentEnd (${newDuration}s)");
    print("Duration change: ${durationChange}s");

    // Update text tracks that come after this video segment
    final textMessages = await _updateTextTracksForSegmentStretch(
      originalSegmentStart,
      originalSegmentEnd,
      newSegmentStart,
      newSegmentEnd,
      durationChange,
    );
    adjustmentMessages.addAll(textMessages);

    // Update audio tracks that come after this video segment
    final audioMessages = await _updateAudioTracksForSegmentStretch(
      originalSegmentStart,
      originalSegmentEnd,
      newSegmentStart,
      newSegmentEnd,
      durationChange,
    );
    adjustmentMessages.addAll(audioMessages);

    print("=== Cascade updates completed ===");
    print("Adjustments made: ${adjustmentMessages.length}");

    return adjustmentMessages;
  }

  Future<List<String>> _updateTextTracksForSegmentStretch(
    double originalSegmentStart,
    double originalSegmentEnd,
    double newSegmentStart,
    double newSegmentEnd,
    double durationChange,
  ) async {
    final adjustmentMessages = <String>[];

    for (int i = 0; i < _textTracks.length; i++) {
      final textTrack = _textTracks[i];
      final textStart = textTrack.trimStartTime;
      final textEnd = textTrack.trimEndTime;

      // Only adjust text tracks that start after the stretched segment
      if (textStart >= originalSegmentEnd) {
        final newStartTime = textStart + durationChange;
        final newEndTime = textEnd + durationChange;

        final updatedTextTrack = textTrack.copyWith(
          startTime: newStartTime,
          endTime: newEndTime,
        );

        _textTracks[i] = updatedTextTrack;
        adjustmentMessages.add(
            "Text track ${i + 1} shifted by ${durationChange.toStringAsFixed(1)}s");

        print(
            "Text track $i adjusted: ${textStart}s-${textEnd}s → ${newStartTime}s-${newEndTime}s");
      }
    }

    return adjustmentMessages;
  }

  Future<List<String>> _updateAudioTracksForSegmentStretch(
    double originalSegmentStart,
    double originalSegmentEnd,
    double newSegmentStart,
    double newSegmentEnd,
    double durationChange,
  ) async {
    final adjustmentMessages = <String>[];

    for (int i = 0; i < _audioTracks.length; i++) {
      final audioTrack = _audioTracks[i];
      final audioStart = audioTrack.trimStartTime;
      final audioEnd = audioTrack.trimEndTime;

      // Only adjust audio tracks that start after the stretched segment
      if (audioStart >= originalSegmentEnd) {
        final newStartTime = audioStart + durationChange;
        final newEndTime = audioEnd + durationChange;

        final updatedAudioTrack = audioTrack.copyWith(
          trimStartTime: newStartTime,
          trimEndTime: newEndTime,
        );

        _audioTracks[i] = updatedAudioTrack;
        adjustmentMessages.add(
            "Audio track ${i + 1} shifted by ${durationChange.toStringAsFixed(1)}s");

        print(
            "Audio track $i adjusted: ${audioStart}s-${audioEnd}s → ${newStartTime}s-${newEndTime}s");
      }
    }

    return adjustmentMessages;
  }

  // Cascade update system for handling overlays when video is trimmed
  Future<List<String>> _cascadeUpdateAfterVideoTrim(
    int videoTrackIndex,
    double originalSegmentStart,
    double originalSegmentEnd,
    double newSegmentStart,
    double newSegmentEnd,
    double trimStart,
    double trimEnd,
  ) async {
    // Validation: Check video track index
    if (videoTrackIndex < 0 || videoTrackIndex >= _videoTracks.length) {
      print(
          "ERROR: Invalid video track index: $videoTrackIndex (total: ${_videoTracks.length})");
      return [];
    }

    // Validation: Check trim parameters
    if (trimStart < 0 || trimEnd <= trimStart) {
      print("ERROR: Invalid trim parameters: start=$trimStart, end=$trimEnd");
      return [];
    }

    final trimOffset = trimStart;
    final newSegmentDuration = trimEnd - trimStart;
    final originalSegmentDuration = originalSegmentEnd - originalSegmentStart;
    final durationChange = newSegmentDuration - originalSegmentDuration;
    final adjustmentMessages = <String>[];

    // Validation: Check segment duration
    if (newSegmentDuration <= 0) {
      print(
          "ERROR: New segment duration is zero or negative: $newSegmentDuration");
      return [];
    }

    // Validation: Check segment bounds
    if (originalSegmentStart >= originalSegmentEnd) {
      print(
          "ERROR: Invalid original segment bounds: start=$originalSegmentStart, end=$originalSegmentEnd");
      return [];
    }

    print("=== Starting segment-aware cascade updates ===");
    print(
        "Video segment $videoTrackIndex: ${originalSegmentStart}s - ${originalSegmentEnd}s (original)");
    print("New timeline position: ${newSegmentStart}s - ${newSegmentEnd}s");
    print(
        "Trim: ${trimStart}s - ${trimEnd}s (duration: ${newSegmentDuration}s)");
    print("Duration change: ${durationChange}s");
    print("Total video segments: ${_videoTracks.length}");
    print("Total text overlays: ${_textTracks.length}");
    print("Total audio tracks: ${_audioTracks.length}");

    // Log all video segments for context
    for (int i = 0; i < _videoTracks.length; i++) {
      final track = _videoTracks[i];
      print(
          "  Segment $i: ${track.startTime}s - ${track.endTime}s (duration: ${track.totalDuration}s)");
    }

    // Log all overlays for context
    for (int i = 0; i < _textTracks.length; i++) {
      final overlay = _textTracks[i];
      print(
          "  Text overlay $i: '${overlay.text}' at ${overlay.trimStartTime}s - ${overlay.trimEndTime}s");
    }

    for (int i = 0; i < _audioTracks.length; i++) {
      final track = _audioTracks[i];
      print(
          "  Audio track $i: ${track.trimStartTime}s - ${track.trimEndTime}s");
    }

    // Update text overlays that intersect with this video segment
    final textMessages = await _updateTextOverlaysForSegmentTrim(
      originalSegmentStart,
      originalSegmentEnd,
      newSegmentStart,
      newSegmentEnd,
      trimOffset,
      newSegmentDuration,
      durationChange,
    );
    adjustmentMessages.addAll(textMessages);

    // Update audio tracks that intersect with this video segment
    final audioMessages = await _updateAudioTracksForSegmentTrim(
      originalSegmentStart,
      originalSegmentEnd,
      newSegmentStart,
      newSegmentEnd,
      trimOffset,
      newSegmentDuration,
      durationChange,
    );
    adjustmentMessages.addAll(audioMessages);

    print("=== Cascade updates completed ===");
    print("Adjustments made: ${adjustmentMessages.length}");

    return adjustmentMessages;
  }

  Future<List<String>> _updateTextOverlaysForSegmentTrim(
    double originalSegmentStart,
    double originalSegmentEnd,
    double newSegmentStart,
    double newSegmentEnd,
    double trimOffset,
    double newSegmentDuration,
    double durationChange,
  ) async {
    final adjustmentMessages = <String>[];

    print("Updating ${_textTracks.length} text overlays for segment trim");

    for (int i = _textTracks.length - 1; i >= 0; i--) {
      final textTrack = _textTracks[i];

      print(
          "Text overlay $i: ${textTrack.trimStartTime}s - ${textTrack.trimEndTime}s");

      // Check if this text overlay intersects with the original video segment
      final overlayStart = textTrack.trimStartTime;
      final overlayEnd = textTrack.trimEndTime;

      // Only process overlays that intersect with this video segment
      if (overlayEnd <= originalSegmentStart ||
          overlayStart >= originalSegmentEnd) {
        print("Text overlay $i: No intersection with segment, skipping");
        continue; // This overlay doesn't intersect with the trimmed segment
      }

      print("Text overlay $i: Intersects with segment, processing...");

      // Simplified logic based on overlay position relative to segment
      if (overlayStart >= originalSegmentEnd) {
        // Case 1: Overlay starts after this segment - shift by duration change
        print(
            "Text overlay $i: After segment - shifting by ${durationChange}s");
        _textTracks[i] = textTrack.copyWith(
          startTime: overlayStart + durationChange,
          endTime: overlayEnd + durationChange,
          updateTimestamp: true,
        );
        adjustmentMessages.add(
            "Shifted text overlay '${textTrack.text}' by ${durationChange}s");
      } else if (overlayEnd <= originalSegmentStart) {
        // Case 2: Overlay ends before this segment - no change needed
        print("Text overlay $i: Before segment - no adjustment needed");
        continue;
      } else if (overlayStart >= originalSegmentStart &&
          overlayEnd <= originalSegmentEnd) {
        // Case 3: Overlay completely within segment - adjust relative to trim
        print("Text overlay $i: Within segment - adjusting for trim");

        final overlayStartInSegment = overlayStart - originalSegmentStart;
        final overlayEndInSegment = overlayEnd - originalSegmentStart;

        // Apply trim offset
        final newStartInSegment =
            (overlayStartInSegment - trimOffset).clamp(0.0, newSegmentDuration);
        final newEndInSegment = (overlayEndInSegment - trimOffset)
            .clamp(newStartInSegment, newSegmentDuration);

        // Convert back to timeline positions (using new segment position)
        final newTimelineStart = newSegmentStart + newStartInSegment;
        final newTimelineEnd = newSegmentStart + newEndInSegment;

        if (newEndInSegment <= 0 || newStartInSegment >= newSegmentDuration) {
          // Overlay is outside trim range - remove it
          _textTracks.removeAt(i);
          adjustmentMessages.add(
              "Removed text overlay '${textTrack.text}' (outside trim range)");
          print("Removed text overlay $i: outside trim range");
        } else {
          // Update positions
          _textTracks[i] = textTrack.copyWith(
            startTime: newTimelineStart,
            endTime: newTimelineEnd,
            updateTimestamp: true,
          );
          adjustmentMessages
              .add("Adjusted text overlay '${textTrack.text}' for trim");
          print(
              "Updated text overlay $i: ${newTimelineStart}s - ${newTimelineEnd}s");
        }
      } else {
        // Case 4: Overlay spans multiple segments - partial adjustment
        print("Text overlay $i: Spans segments - applying partial adjustment");

        if (overlayStart < originalSegmentStart &&
            overlayEnd > originalSegmentEnd) {
          // Overlay spans this entire segment - adjust for duration change
          final newOverlayEnd = overlayEnd + durationChange;
          _textTracks[i] = textTrack.copyWith(
            startTime: overlayStart, // Keep original start
            endTime: newOverlayEnd,
            updateTimestamp: true,
          );
          adjustmentMessages.add(
              "Partially adjusted text overlay '${textTrack.text}' (spans segment)");
          print(
              "Partially adjusted text overlay $i: ${overlayStart}s - ${newOverlayEnd}s");
        } else if (overlayStart < originalSegmentStart) {
          // Overlay starts before segment and ends within it - adjust end
          final overlayEndInSegment = overlayEnd - originalSegmentStart;
          final newEndInSegment =
              (overlayEndInSegment - trimOffset).clamp(0.0, newSegmentDuration);
          final newTimelineEnd = newSegmentStart + newEndInSegment;

          _textTracks[i] = textTrack.copyWith(
            startTime: overlayStart, // Keep original start
            endTime: newTimelineEnd,
            updateTimestamp: true,
          );
          adjustmentMessages
              .add("Adjusted end of text overlay '${textTrack.text}'");
          print(
              "Adjusted overlay end $i: ${overlayStart}s - ${newTimelineEnd}s");
        } else {
          // Overlay starts within segment and ends after it - adjust start and shift
          final overlayStartInSegment = overlayStart - originalSegmentStart;
          final newStartInSegment = (overlayStartInSegment - trimOffset)
              .clamp(0.0, newSegmentDuration);
          final newTimelineStart = newSegmentStart + newStartInSegment;
          final newTimelineEnd = overlayEnd + durationChange;

          _textTracks[i] = textTrack.copyWith(
            startTime: newTimelineStart,
            endTime: newTimelineEnd,
            updateTimestamp: true,
          );
          adjustmentMessages.add(
              "Adjusted start and shifted text overlay '${textTrack.text}'");
          print(
              "Adjusted overlay start+shift $i: ${newTimelineStart}s - ${newTimelineEnd}s");
        }
      }
    }

    return adjustmentMessages;
  }

  Future<List<String>> _updateAudioTracksForSegmentTrim(
    double originalSegmentStart,
    double originalSegmentEnd,
    double newSegmentStart,
    double newSegmentEnd,
    double trimOffset,
    double newSegmentDuration,
    double durationChange,
  ) async {
    final adjustmentMessages = <String>[];

    print("Updating ${_audioTracks.length} audio tracks for segment trim");

    for (int i = _audioTracks.length - 1; i >= 0; i--) {
      final audioTrack = _audioTracks[i];

      print(
          "Audio track $i: ${audioTrack.trimStartTime}s - ${audioTrack.trimEndTime}s");

      // Check if this audio track intersects with the original video segment
      final trackStart = audioTrack.trimStartTime;
      final trackEnd = audioTrack.trimEndTime;

      // Only process tracks that intersect with this video segment
      if (trackEnd <= originalSegmentStart ||
          trackStart >= originalSegmentEnd) {
        print("Audio track $i: No intersection with segment, skipping");
        continue; // This track doesn't intersect with the trimmed segment
      }

      print("Audio track $i: Intersects with segment, processing...");

      // Simplified logic based on track position relative to segment
      if (trackStart >= originalSegmentEnd) {
        // Case 1: Track starts after this segment - shift by duration change
        print("Audio track $i: After segment - shifting by ${durationChange}s");
        _audioTracks[i] = audioTrack.copyWith(
          trimStartTime: trackStart + durationChange,
          trimEndTime: trackEnd + durationChange,
          updateTimestamp: true,
        );
        adjustmentMessages.add("Shifted audio track by ${durationChange}s");
      } else if (trackEnd <= originalSegmentStart) {
        // Case 2: Track ends before this segment - no change needed
        print("Audio track $i: Before segment - no adjustment needed");
        continue;
      } else if (trackStart >= originalSegmentStart &&
          trackEnd <= originalSegmentEnd) {
        // Case 3: Track completely within segment - adjust relative to trim
        print("Audio track $i: Within segment - adjusting for trim");

        final trackStartInSegment = trackStart - originalSegmentStart;
        final trackEndInSegment = trackEnd - originalSegmentStart;

        // Apply trim offset
        final newStartInSegment =
            (trackStartInSegment - trimOffset).clamp(0.0, newSegmentDuration);
        final newEndInSegment = (trackEndInSegment - trimOffset)
            .clamp(newStartInSegment, newSegmentDuration);

        // Convert back to timeline positions (using new segment position)
        final newTimelineStart = newSegmentStart + newStartInSegment;
        final newTimelineEnd = newSegmentStart + newEndInSegment;

        if (newEndInSegment <= 0 || newStartInSegment >= newSegmentDuration) {
          // Track is outside trim range - remove it
          _audioTracks.removeAt(i);
          adjustmentMessages.add("Removed audio track (outside trim range)");
          print("Removed audio track $i: outside trim range");
        } else {
          // Update positions
          _audioTracks[i] = audioTrack.copyWith(
            trimStartTime: newTimelineStart,
            trimEndTime: newTimelineEnd,
            totalDuration: newTimelineEnd - newTimelineStart,
            updateTimestamp: true,
          );
          adjustmentMessages.add("Adjusted audio track for trim");
          print(
              "Updated audio track $i: ${newTimelineStart}s - ${newTimelineEnd}s");
        }
      } else {
        // Case 4: Track spans multiple segments - partial adjustment
        print("Audio track $i: Spans segments - applying partial adjustment");

        if (trackStart < originalSegmentStart &&
            trackEnd > originalSegmentEnd) {
          // Track spans this entire segment - adjust for duration change
          final newTrackEnd = trackEnd + durationChange;
          _audioTracks[i] = audioTrack.copyWith(
            trimStartTime: trackStart, // Keep original start
            trimEndTime: newTrackEnd,
            totalDuration: newTrackEnd - trackStart,
            updateTimestamp: true,
          );
          adjustmentMessages
              .add("Partially adjusted audio track (spans segment)");
          print(
              "Partially adjusted audio track $i: ${trackStart}s - ${newTrackEnd}s");
        } else if (trackStart < originalSegmentStart) {
          // Track starts before segment and ends within it - adjust end
          final trackEndInSegment = trackEnd - originalSegmentStart;
          final newEndInSegment =
              (trackEndInSegment - trimOffset).clamp(0.0, newSegmentDuration);
          final newTimelineEnd = newSegmentStart + newEndInSegment;

          _audioTracks[i] = audioTrack.copyWith(
            trimStartTime: trackStart, // Keep original start
            trimEndTime: newTimelineEnd,
            totalDuration: newTimelineEnd - trackStart,
            updateTimestamp: true,
          );
          adjustmentMessages.add("Adjusted end of audio track");
          print("Adjusted track end $i: ${trackStart}s - ${newTimelineEnd}s");
        } else {
          // Track starts within segment and ends after it - adjust start and shift
          final trackStartInSegment = trackStart - originalSegmentStart;
          final newStartInSegment =
              (trackStartInSegment - trimOffset).clamp(0.0, newSegmentDuration);
          final newTimelineStart = newSegmentStart + newStartInSegment;
          final newTimelineEnd = trackEnd + durationChange;

          _audioTracks[i] = audioTrack.copyWith(
            trimStartTime: newTimelineStart,
            trimEndTime: newTimelineEnd,
            totalDuration: newTimelineEnd - newTimelineStart,
            updateTimestamp: true,
          );
          adjustmentMessages.add("Adjusted start and shifted audio track");
          print(
              "Adjusted track start+shift $i: ${newTimelineStart}s - ${newTimelineEnd}s");
        }
      }
    }

    return adjustmentMessages;
  }

  Future<void> addText(BuildContext context) async {
    _textFieldVisibility = false;
    _sendButtonVisibility = false;
    final text = _textEditingController.text.trim();
    _textEditingController.clear();
    if (text.isEmpty) return;

    // Default to 3 seconds, addTextTrack will handle smart duration logic
    await addTextTrack(context, text, 3.0);
  }

  Future<void> addTextTrack(
      BuildContext context, String text, double requestedDuration,
      {int? targetLane}) async {
    // Pre-check: Do we have available space in any lane at current position?
    final availableSpace = getAvailableTextSpaceAtCurrentPosition();

    if (availableSpace == null) {
      // No space available in any lane at current position
      showSnackBar(
        context,
        "Cannot add text: All lanes occupied at current position. "
        "Move playhead or remove existing text tracks.",
      );
      return;
    }

    // Show info about available space
    final currentPosition = _masterTimelineController.currentTimelinePosition;
    print(
        '📊 Available text space: ${availableSpace.duration.toStringAsFixed(1)}s in Lane ${availableSpace.laneIndex} at ${currentPosition.toStringAsFixed(1)}s');

    // Use the best available duration (collision-aware)
    final actualDuration = min(requestedDuration, availableSpace.duration);
    final startTime = currentPosition;
    final endTime = startTime + actualDuration;

    final textTrack = TextTrackModel(
      text: text,
      trimStartTime: startTime,
      trimEndTime: endTime,
      position: getDefaultTextPosition(),
      laneIndex: availableSpace.laneIndex,
    );

    print(
        '✅ Adding text track to lane ${availableSpace.laneIndex}: ${startTime.toStringAsFixed(1)}s-${endTime.toStringAsFixed(1)}s (${actualDuration.toStringAsFixed(1)}s)');
    _textTracks.add(textTrack);
    _showTextInTimeline = true;
    _updateMasterTimeline(preservePosition: true);
    notifyListeners();
  }

  Future<void> removeTextTrack(int index) async {
    if (index < 0 || index >= _textTracks.length) {
      print('⚠️ Invalid index for removeTextTrack: $index');
      return;
    }

    final removedTrack = _textTracks[index];
    print(
        '🗑️ Removing text track at index $index (Lane ${removedTrack.laneIndex})');

    _textTracks.removeAt(index);

    // CRITICAL: Compact lanes after deletion to remove gaps
    _compactTextLanes();

    // Clear selection if deleted track was selected
    if (_selectedTextTrackIndex == index) {
      _selectedTextTrackIndex = -1;
      exitEditMode();
    } else if (_selectedTextTrackIndex != null &&
        _selectedTextTrackIndex! > index) {
      // Adjust selected index if after deleted track
      _selectedTextTrackIndex = _selectedTextTrackIndex! - 1;
    }

    // Clear displayed text and hide timeline if empty
    if (_textTracks.isEmpty) {
      _layeredTextOnVideo = '';
      _showTextInTimeline = false;
    }

    print('✅ Text track removed. Remaining tracks: ${_textTracks.length}');
    notifyListeners();
  }

  Future<void> updateTextTrack(
    int index,
    double startTime,
    double endTime,
  ) async {
    _textTracks[index] = _textTracks[index].copyWith(
      startTime: startTime,
      endTime: endTime,
    );
    notifyListeners();
  }

  Future<void> updateTextTrackModel(
    int index,
    TextTrackModel updatedTrack,
  ) async {
    _textTracks[index] = updatedTrack;
    notifyListeners();
  }

  /// Attempt to switch text track to different lane with smart placement
  /// Automatically finds nearest available gap if desired position is occupied
  /// Returns true if successful, false if no space available in target lane
  Future<bool> attemptTextLaneSwitch(
    BuildContext context,
    int trackIndex,
    int fromLane,
    int toLane, {
    bool autoTrim = true,
  }) async {
    if (trackIndex < 0 || trackIndex >= _textTracks.length) return false;
    if (toLane < 0 || toLane >= maxLanes) return false;
    if (fromLane == toLane) return true; // No change needed

    final track = _textTracks[trackIndex];
    final trackDuration = track.trimEndTime - track.trimStartTime;
    final currentStartTime = track.trimStartTime;

    print(
        '🎯 Attempting lane switch: $fromLane → $toLane at ${currentStartTime.toStringAsFixed(1)}s (${trackDuration.toStringAsFixed(1)}s)');

    // Smart placement: find best position in target lane
    final placement =
        findSmartPlacementInLane(toLane, currentStartTime, trackDuration);

    if (placement == null) {
      // No space at all in target lane
      print('❌ Cannot switch to lane $toLane: Lane is fully occupied');
      // Snackbar removed as per user request
      return false;
    }

    // Place track at smart position
    _textTracks[trackIndex] = track.copyWith(
      startTime: placement.startTime,
      endTime: placement.startTime + placement.duration,
      laneIndex: toLane,
      updateTimestamp: true,
    );

    // Provide feedback only if position or duration changed significantly
    final positionChanged =
        (placement.startTime - currentStartTime).abs() > 0.1;
    final durationChanged = (placement.duration - trackDuration).abs() > 0.1;

    if (positionChanged || durationChanged) {
      String message = "Moved to Lane ${toLane + 1}";

      if (positionChanged) {
        message += " at ${placement.startTime.toStringAsFixed(1)}s";
      }

      if (durationChanged) {
        message += " (trimmed to ${placement.duration.toStringAsFixed(1)}s)";
      }

      // Snackbar removed as per user request
      print('📍 $message');
    } else {
      print('✅ Switched track to lane $toLane at same position');
    }

    // CRITICAL: Compact lanes after switch (may have created gap in fromLane)
    _compactTextLanes();

    notifyListeners();
    return true;
  }

  void toggleAudioMute(String audioId) {
    _masterTimelineController.toggleAudioMute(audioId);
    notifyListeners();
  }

  bool isAudioMuted(String audioId) {
    return _masterTimelineController.isAudioMuted(audioId);
  }

  /// Create audio controllers for all audio tracks
  Future<void> _createAudioControllers() async {
    // Dispose old controllers
    for (var controller in _audioControllers.values) {
      controller.dispose();
    }
    _audioControllers.clear();

    // Create new controllers for each audio track
    for (var track in _audioTracks) {
      final controller = PlayerController();
      await controller.preparePlayer(path: track.audioFile.path);
      _audioControllers[track.id] = controller;

      // Reapply mute state from master timeline controller
      final isMuted = _masterTimelineController.isAudioMuted(track.id);
      controller.setVolume(isMuted ? 0.0 : 1.0);
    }
  }

  /// Helper method to update master timeline with both video and audio data
  void _updateMasterTimeline({bool preservePosition = false}) {
    _masterTimelineController.initialize(
      tracks: _videoTracks,
      controllers: _videoControllers,
      audioTracks: _audioTracks,
      audioControllers: _audioControllers,
      preservePosition: preservePosition,
    );
  }

  // Canvas text overlay methods

  /// Update text track position for canvas mode
  void updateTextTrackPosition(int index, Offset newPosition) {
    if (index >= 0 && index < _textTracks.length) {
      _textTracks[index] = _textTracks[index].copyWith(
        position: newPosition,
        updateTimestamp: true,
      );
      notifyListeners();
    }
  }

  /// Update text track rotation for canvas mode
  void updateTextTrackRotation(int index, double rotation) {
    if (index >= 0 && index < _textTracks.length) {
      _textTracks[index] = _textTracks[index].copyWith(
        rotation: rotation,
        updateTimestamp: true,
      );
      notifyListeners();
    }
  }

  /// Add text track at specific canvas position
  Future<void> addTextTrackAtPosition(
      String text, double duration, Offset position) async {
    final double startTime =
        _textTracks.isNotEmpty ? _textTracks.last.trimEndTime : 0;

    final textTrack = TextTrackModel(
      text: text,
      trimStartTime: startTime,
      trimEndTime: startTime + duration,
      position: position,
    );

    _textTracks.add(textTrack);
    initializeOrResetControllers();
    notifyListeners();
  }

  /// Convert canvas coordinates to video-relative coordinates
  Offset convertCanvasToVideoCoordinates(
      Offset canvasPosition, String? videoId) {
    if (videoId == null || !_useMultiVideoCanvas) {
      // For sequential mode or no specific video, use direct coordinates
      return canvasPosition;
    }

    // Find the video track
    final videoTrackIndex =
        _videoTracks.indexWhere((track) => track.id == videoId);
    if (videoTrackIndex == -1) {
      return canvasPosition;
    }

    final videoTrack = _videoTracks[videoTrackIndex];
    final videoController = _videoControllers[videoId];

    if (videoController?.video.value.isInitialized != true) {
      return canvasPosition;
    }

    final videoSize = videoController!.video.value.size;

    // Convert from canvas coordinates to video-relative coordinates
    final relativeX = (canvasPosition.dx - videoTrack.canvasPosition.dx) /
        (videoTrack.canvasSize.width * videoTrack.canvasScale);
    final relativeY = (canvasPosition.dy - videoTrack.canvasPosition.dy) /
        (videoTrack.canvasSize.height * videoTrack.canvasScale);

    return Offset(
      relativeX * videoSize.width,
      relativeY * videoSize.height,
    );
  }

  /// Convert video-relative coordinates to canvas coordinates
  Offset convertVideoToCanvasCoordinates(
      Offset videoPosition, String? videoId) {
    if (videoId == null || !_useMultiVideoCanvas) {
      // For sequential mode or no specific video, use direct coordinates
      return videoPosition;
    }

    // Find the video track
    final videoTrackIndex =
        _videoTracks.indexWhere((track) => track.id == videoId);
    if (videoTrackIndex == -1) {
      return videoPosition;
    }

    final videoTrack = _videoTracks[videoTrackIndex];
    final videoController = _videoControllers[videoId];

    if (videoController?.video.value.isInitialized != true) {
      return videoPosition;
    }

    final videoSize = videoController!.video.value.size;

    // Convert from video-relative coordinates to canvas coordinates
    final relativeX = videoPosition.dx / videoSize.width;
    final relativeY = videoPosition.dy / videoSize.height;

    return Offset(
      videoTrack.canvasPosition.dx +
          (relativeX * videoTrack.canvasSize.width * videoTrack.canvasScale),
      videoTrack.canvasPosition.dy +
          (relativeY * videoTrack.canvasSize.height * videoTrack.canvasScale),
    );
  }

  /// Check if text track is attached to a specific video
  bool isTextAttachedToVideo(int textIndex, String videoId) {
    // For now, text tracks are global. This method can be extended
    // if we add per-video text attachment in the future
    return false;
  }

  /// Get the recommended text position on canvas (center-bottom)
  Offset getDefaultTextPosition() {
    // Use dynamic canvas size that fits optimally in the preview container
    final canvasSize = _canvasSize.isEmpty
        ? _selectedCanvasRatio.exportSize
        : // Fallback during initialization
        _selectedCanvasRatio.getOptimalCanvasSize(_canvasSize);
    // Center-bottom of canvas with padding from bottom edge
    return Offset(canvasSize.width / 2, canvasSize.height - 30);
  }

  // Cleanup
  @override
  void dispose() {
    // _videoEditorController?.removeListener(_onVideoPositionChanged);
    _videoEditorController?.removeListener(listenVideoPosition);
    _positionTimer?.cancel();
    _videoEditorController?.dispose();
    _audioController?.dispose();

    // Dispose all centralized audio controllers
    for (var controller in _audioControllers.values) {
      controller.dispose();
    }
    _audioControllers.clear();

    // Dispose all cached images
    for (var image in _imageCache.values) {
      image.dispose();
    }
    _imageCache.clear();

    // Dispose master timeline controller
    _masterTimelineController.dispose();

    _videoScrollController?.dispose();
    _audioScrollController?.dispose();
    _textScrollController?.dispose();
    _bottomScrollController?.dispose();
    _textEditingController.dispose();
    super.dispose();
  }

  // Helper to read debug logs from file
  Future<String> _readLogs() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logFile = File('${dir.path}/video_export_debug.log');
      if (await logFile.exists()) {
        return await logFile.readAsString();
      } else {
        return 'No log file found';
      }
    } catch (e) {
      return 'Error reading log: $e';
    }
  }

  // Method to get logs for debugging (can be called from UI)
  Future<String> getDebugLogs() async {
    return await _readLogs();
  }

  // Helper method to merge audio tracks with the combined video
  Future<String?> _mergeAudioTracksWithVideo(String videoPath,
      {bool muteOriginal = false}) async {
    final tempDir = await getTemporaryDirectory();

    await _writeLog('=== Starting _mergeAudioTracksWithVideo ===');
    await _writeLog('Input video path: $videoPath');
    await _writeLog('Number of audio tracks to merge: ${_audioTracks.length}');
    await _writeLog(
        'Note: Preserving video dimensions from VideoExportManager (no re-scaling)');

    print('=== Starting _mergeAudioTracksWithVideo ===');
    print('Input video path: $videoPath');
    print('Number of audio tracks to merge: ${_audioTracks.length}');
    print('✅ Preserving video dimensions (no re-scaling during audio merge)');

    // Log multi-lane audio structure
    if (_audioTracks.isNotEmpty) {
      final laneGroups = <int, List<AudioTrackModel>>{};
      for (var track in _audioTracks) {
        laneGroups.putIfAbsent(track.laneIndex, () => []).add(track);
      }
      print('📊 Multi-lane audio structure:');
      for (var laneIndex in laneGroups.keys.toList()..sort()) {
        final tracksInLane = laneGroups[laneIndex]!;
        print('   Lane $laneIndex: ${tracksInLane.length} track(s)');
        for (var track in tracksInLane) {
          print(
              '     - ${track.trimStartTime.toStringAsFixed(1)}s to ${track.trimEndTime.toStringAsFixed(1)}s${isAudioMuted(track.id) ? " (MUTED)" : ""}');
        }
      }
    }

    // Ensure the input video has an audio stream (even if silent)
    final videoWithAudio = await ensureAudio(File(videoPath));
    String inputFiles = '-i "${videoWithAudio.path}" ';
    String filterComplex = '';
    List<String> audioInputs = [];

    // Add all audio files as inputs
    for (int i = 0; i < _audioTracks.length; i++) {
      var track = _audioTracks[i];
      inputFiles += '-i "${track.audioFile.path}" ';
      await _writeLog(
          'Added audio input $i (Lane ${track.laneIndex}): ${track.audioFile.path}');
      print(
          '🎵 Added audio input $i (Lane ${track.laneIndex}): ${track.audioFile.path}');
    }

    // REMOVED: Video scaling filter - video is already at correct dimensions from VideoExportManager
    // The input video has already been processed with proper canvas transforms, rotation, etc.
    // Re-scaling here would distort the carefully positioned content

    // Check if original video has audio (not just silent audio stream)
    final hasAudio = await _hasAudioStream(videoWithAudio.path);
    await _writeLog('Original video has audio: $hasAudio');
    print('Original video has audio: $hasAudio');

    // Handle original video audio only if it exists and not muted
    if (hasAudio && !muteOriginal) {
      filterComplex += '[0:a]volume=1[orig]; ';
      audioInputs.add('[orig]');
    }

    // Handle additional audio tracks with delays, duration trimming, and mute
    for (int i = 0; i < _audioTracks.length; i++) {
      var track = _audioTracks[i];
      int delayMs = (track.trimStartTime * 1000).toInt();
      final isMuted = isAudioMuted(track.id);
      final volume = isMuted ? 0 : 1.0;

      // Calculate the trimmed duration of the audio track
      final audioDuration = track.trimEndTime - track.trimStartTime;

      // Add detailed logging for trim validation
      await _writeLog('Audio track $i trim details:');
      await _writeLog('  File: ${track.audioFile.path}');
      await _writeLog('  Original totalDuration: ${track.totalDuration}s');
      await _writeLog(
          '  Trim range: ${track.trimStartTime}s - ${track.trimEndTime}s');
      await _writeLog('  Calculated trimmed duration: ${audioDuration}s');
      await _writeLog('  Timeline position (delay): ${delayMs}ms');

      print('🎵 Audio track $i (Lane ${track.laneIndex}) trim details:');
      print(
          '  Original duration: ${track.totalDuration}s, Trimmed duration: ${audioDuration}s');
      print(
          '  Timeline position: ${track.trimStartTime}s-${track.trimEndTime}s (delay: ${delayMs}ms)');

      await _writeLog(
          'Audio track $i (Lane ${track.laneIndex}): delay=${delayMs}ms, duration=${audioDuration}s, volume=$volume');
      print(
          '🔊 Audio track $i (Lane ${track.laneIndex}): delay=${delayMs}ms, duration=${audioDuration}s, volume=$volume');

      if (delayMs > 0) {
        // Apply delay, trim duration, and volume
        filterComplex +=
            '[${i + 1}:a]atrim=duration=$audioDuration,adelay=${delayMs}|${delayMs},volume=$volume[a${i + 1}]; ';
      } else {
        // Apply duration trim and volume only
        filterComplex +=
            '[${i + 1}:a]atrim=duration=$audioDuration,volume=$volume[a${i + 1}]; ';
      }
      audioInputs.add('[a${i + 1}]');
    }

    String outputPath =
        '${tempDir.path}/export_${DateTime.now().millisecondsSinceEpoch}.mp4';

    String command;
    if (audioInputs.length > 1) {
      // Mix all audio inputs - use duration=first to match video duration
      filterComplex +=
          '${audioInputs.join('')}amix=inputs=${audioInputs.length}:duration=first:normalize=1[mixout]';
      // Use stream copy for video (preserve dimensions and quality from VideoExportManager)
      command =
          '$inputFiles -filter_complex "$filterComplex" -map "0:v" -map "[mixout]" -c:v copy -c:a aac -b:a 256k -ar 48000 "$outputPath"';
    } else if (audioInputs.length == 1) {
      // Only one audio source (original or one additional)
      String audioMap = audioInputs.first;
      // Use stream copy for video (preserve dimensions and quality from VideoExportManager)
      command =
          '$inputFiles -filter_complex "$filterComplex" -map "0:v" -map "$audioMap" -c:v copy -c:a aac -b:a 256k -ar 48000 "$outputPath"';
    } else {
      // No audio - use stream copy for video
      command = '$inputFiles -map "0:v" -an -c:v copy "$outputPath"';
    }

    await _writeLog('FFmpeg command (audio mixing): $command');
    await _writeLog('Filter complex: $filterComplex');
    print('FFmpeg command (audio mixing): $command');
    print('Filter complex: $filterComplex');

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    final ffmpegOutput = await session.getOutput();
    print('FFmpeg output:');
    print(ffmpegOutput);
    await _writeLog('FFmpeg output: $ffmpegOutput');
    if (ReturnCode.isSuccess(returnCode)) {
      await _writeLog('Successfully created mixed audio output: $outputPath');
      print('Successfully created mixed audio output: $outputPath');
      return outputPath;
    } else {
      final logs = await session.getOutput();
      await _writeLog('FFmpeg error: $logs');
      print('FFmpeg error: $logs');
      return null;
    }
  }

  /// Directly export the combined video file after combineMediaFiles, skipping all post-processing
  Future<String?> exportCombinedVideoDirectly(String outputPath) async {
    // Get target dimensions
    final targetSize = _getAspectRatioDimensions();
    final processedFiles = _videoTracks.map((t) => t.processedFile).toList();
    final (
      File? combined,
      List<(File, File)>? processedPairs,
    ) = await EditorVideoController.combineMediaFiles(
      processedFiles,
      outputHeight: targetSize.height.toInt(),
      outputWidth: targetSize.width.toInt(),
    );
    if (combined == null) {
      print('Failed to combine video segments for direct export');
      return null;
    }
    print(
        'Direct export: combined file path: \\${combined.path}, size: \\${await combined.length()} bytes');
    final outputFile = await File(combined.path).copy(outputPath);
    print(
        'Direct export: output file path: \\${outputFile.path}, size: \\${await outputFile.length()} bytes');
    return outputFile.path;
  }

  /// Process individual video segments for mute state before combining
  Future<List<File>> processVideoSegmentsForMute() async {
    final tempDir = await getTemporaryDirectory();
    final List<File> processedSegments = [];

    print('=== Processing video segments for mute state ===');
    print('Total segments: ${_videoTracks.length}');

    for (int i = 0; i < _videoTracks.length; i++) {
      final track = _videoTracks[i];
      final isMuted = isVideoMuted(track.id);

      print(
          'Segment $i: id=${track.id}, muted=$isMuted, path=${track.processedFile.path}');

      if (isMuted) {
        // Step 1: Set original audio volume to 0
        final tempMutedPath =
            '${tempDir.path}/temp_muted_segment_${i}_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final volumeMuteCmd =
            '-y -i "${track.processedFile.path}" -af "volume=0" -c:v copy -c:a aac "$tempMutedPath"';
        print('Muting original audio for segment $i: $volumeMuteCmd');
        final muteSession = await FFmpegKit.execute(volumeMuteCmd);
        final muteReturnCode = await muteSession.getReturnCode();
        if (!ReturnCode.isSuccess(muteReturnCode)) {
          print('Failed to mute original audio for segment $i, using original');
          processedSegments.add(track.processedFile);
          continue;
        }

        // Step 2: Add silent audio using anullsrc
        final mutedPath =
            '${tempDir.path}/muted_segment_${i}_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final anullsrcCmd =
            '-y -i "$tempMutedPath" -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000 -shortest -c:v copy -c:a aac "$mutedPath"';
        print('Adding silent audio for segment $i: $anullsrcCmd');
        final anullsrcSession = await FFmpegKit.execute(anullsrcCmd);
        final anullsrcReturnCode = await anullsrcSession.getReturnCode();
        if (ReturnCode.isSuccess(anullsrcReturnCode)) {
          processedSegments.add(File(mutedPath));
          print('Muted segment $i processed successfully: $mutedPath');
          // Verify the muted segment has silent audio
          final verifySession =
              await FFmpegKit.execute('-i "$mutedPath" -hide_banner');
          final verifyOutput = await verifySession.getOutput() ?? '';
          final verifyLogs = await verifySession.getLogsAsString();
          final allVerifyOutput = verifyOutput + verifyLogs;
          print(
              'Muted segment $i audio check: ${allVerifyOutput.contains('Audio:') ? 'Has audio stream' : 'No audio stream'}');
          if (allVerifyOutput.contains('Audio:')) {
            print(
                'Muted segment $i audio details: ${allVerifyOutput.split('Audio:').last.split('\n').first}');
          }
        } else {
          print('Failed to add silent audio for segment $i, using original');
          processedSegments.add(track.processedFile);
        }
      } else {
        // Keep original audio for unmuted segments
        processedSegments.add(track.processedFile);
        print('Unmuted segment $i: keeping original audio');
      }
    }

    print('=== Finished processing video segments ===');
    return processedSegments;
  }

  // Canvas manipulation methods

  /// Select a media element for manipulation
  void selectMediaForManipulation(String? mediaId) {
    _selectedMediaId = mediaId;
    _showManipulationHandles = mediaId != null;
    notifyListeners();
  }

  /// Get currently selected media ID
  String? get selectedMediaId => _selectedMediaId;

  /// Check if manipulation handles should be shown
  bool get showManipulationHandles => _showManipulationHandles;

  /// Update canvas properties for a video track
  void updateVideoTrackCanvasTransform(
    String trackId, {
    Offset? position,
    Size? size,
    double? scale,
    int? rotation,
    Rect? cropRect,
    double? opacity,
  }) {
    final index = _videoTracks.indexWhere((t) => t.id == trackId);
    if (index == -1) return;

    final track = _videoTracks[index];

    // Convert Rect to CropModel if cropRect is provided
    CropModel? cropModel;
    if (cropRect != null) {
      // Get video size from controller if available
      final videoController = _videoControllers[trackId];
      Size videoSize = const Size(1920, 1080); // Default fallback
      if (videoController?.video.value.isInitialized == true) {
        videoSize = videoController!.video.value.size;
      }

      cropModel = CropModel.fromRect(cropRect, videoSize, enabled: true);
    }

    final updatedTrack = track.copyWith(
      canvasPosition: position,
      canvasSize: size,
      canvasScale: scale,
      canvasRotation: rotation,
      canvasCropModel: cropModel,
      canvasOpacity: opacity,
    );

    _videoTracks[index] = updatedTrack;

    // Update the master timeline controller if needed (preserve position during track updates)
    if (_masterTimelineController.videoTracks.isNotEmpty) {
      _updateMasterTimeline(preservePosition: true);
    }

    notifyListeners();
  }

  /// Update canvas properties for a video track using VideoTrackModel
  void updateVideoTrackFromModel(VideoTrackModel updatedTrack) {
    updateVideoTrackCanvasTransform(
      updatedTrack.id,
      position: updatedTrack.canvasPosition,
      size: updatedTrack.canvasSize,
      scale: updatedTrack.canvasScale,
      rotation: updatedTrack.canvasRotation,
      cropRect: updatedTrack.canvasCropRect,
      opacity: updatedTrack.canvasOpacity,
    );
  }

  /// Reset canvas transformation for a track
  void resetTrackCanvasTransform(String trackId) {
    final index = _videoTracks.indexWhere((t) => t.id == trackId);
    if (index == -1) return;

    final track = _videoTracks[index];

    // Calculate default size based on canvas size
    final defaultSize = _calculateAutoSize(track, _canvasSize);
    final defaultPosition = _calculateAutoPosition(index, _canvasSize);

    updateVideoTrackCanvasTransform(
      trackId,
      position: defaultPosition,
      size: defaultSize,
      scale: 1.0,
      rotation: 0,
      cropRect: const Rect.fromLTWH(0, 0, 1, 1),
      opacity: 1.0,
    );
  }

  /// Get current video track at timeline position
  VideoTrackModel? getCurrentVideoTrack() {
    final (currentTrack, _) =
        _masterTimelineController.getCurrentVideoAndPosition();
    return currentTrack;
  }

  /// Check if a track is currently playing
  bool isTrackCurrentlyPlaying(String trackId) {
    final currentTrack = getCurrentVideoTrack();
    return currentTrack?.id == trackId;
  }
}

extension ListStack<T> on List<T> {
  void push(T item) {
    add(item);
  }

  T pop() {
    if (isEmpty) {
      throw StateError('Cannot pop from an empty stack');
    }
    return removeLast();
  }

  void clearStack() => clear();
}

class EditOperation {
  final EditOperationType type;
  final dynamic oldState;
  final dynamic newState;

  EditOperation(this.type, this.oldState, this.newState);

  EditOperation reverse() => EditOperation(type, newState, oldState);
}

enum EditOperationType {
  text,
  filter,
  trim,
  crop,
  rotation,
  transition,
  speed,
  asset,
  caption,
  stretch,
}

enum EditMode {
  none, // Default mode, no editing operation active
  trim, // Trimming video duration
  crop, // Cropping video frame
  text, // Adding/editing text overlays
  filter, // Applying visual filters
  transition, // Adding/editing transitions
  audio, // Editing audio/sound
  speed, // Adjusting playback speed
  rotate, // Rotating video
  asset, // Managing assets (images/videos)
  volume, // Adjusting volume levels
  caption, // Adding/editing captions
}
