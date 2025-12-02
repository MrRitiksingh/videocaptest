import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ai_video_creator_editor/controllers/video_controller.dart';
import 'package:ai_video_creator_editor/screens/project/models/video_track_model.dart';
import 'package:ai_video_creator_editor/screens/project/models/audio_track_model.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/transition_picker.dart';
import 'package:audio_waveforms/audio_waveforms.dart';

/// Represents the current transition state during playback
class TransitionPlaybackState {
  final bool isInTransition;
  final TransitionType? transitionType;
  final double progress; // 0.0 to 1.0, where 0.0 is start and 1.0 is end
  final int fromTrackIndex;
  final int toTrackIndex;
  final double transitionDuration;

  const TransitionPlaybackState({
    required this.isInTransition,
    this.transitionType,
    this.progress = 0.0,
    this.fromTrackIndex = -1,
    this.toTrackIndex = -1,
    this.transitionDuration = 1.0,
  });

  /// Create a "no transition" state
  factory TransitionPlaybackState.none() {
    return const TransitionPlaybackState(
      isInTransition: false,
    );
  }

  @override
  String toString() {
    if (!isInTransition) return 'TransitionPlaybackState(none)';
    return 'TransitionPlaybackState(${transitionType?.name}, progress: ${(progress * 100).toStringAsFixed(1)}%, from: $fromTrackIndex, to: $toTrackIndex)';
  }
}

/// Master controller for managing sequential video playback timeline
class MasterTimelineController {
  // Core state
  double _currentTimelinePosition =
      0.0; // Position in seconds across all videos
  bool _isPlaying = false;
  Timer? _playbackTimer;
  Timer? _positionUpdateTimer;
  bool _isDisposed = false; // Track if controller is disposed
  TransitionPlaybackState _currentTransitionState = TransitionPlaybackState.none();

  // Video tracks and controllers
  final List<VideoTrackModel> _videoTracks = [];
  final Map<String, VideoEditorController> _videoControllers = {};
  final Set<String> _activeControllerIds =
      {}; // Track which controllers are actively being used
  final Set<String> _disposedControllerIds = {}; // Track disposed controllers

  // Audio tracks and controllers
  final List<AudioTrackModel> _audioTracks = [];
  final Map<String, PlayerController> _audioControllers = {};
  final Set<String> _activeAudioControllerIds =
      {}; // Track which audio controllers are actively being used
  final Set<String> _disposedAudioControllerIds =
      {}; // Track disposed audio controllers

  // Unified mute states
  final Map<String, bool> _videoMuteStates = {};
  final Map<String, bool> _audioMuteStates = {};

  // Callbacks
  VoidCallback? onPositionChanged;
  VoidCallback? onPlayStateChanged;
  Function(List<String>)?
      onDisposeUnusedControllers; // Callback to dispose unused controllers
  Future<void> Function(String trackId)?
      onRecreateController; // Callback to recreate missing controllers

  // Current video tracking
  String? _currentTrackId;

  // Debouncing
  Timer? _seekDebounceTimer;
  bool _isSeeking = false;

  // Disposal synchronization
  final Set<String> _pendingDisposalIds = {};

  // Getters
  double get currentTimelinePosition => _currentTimelinePosition;
  bool get isPlaying => _isPlaying;
  List<VideoTrackModel> get videoTracks => _videoTracks;
  List<AudioTrackModel> get audioTracks => _audioTracks;
  double get totalDuration => _videoTracks.fold(0.0, (sum, track) {
        final duration = track.isImageBased && track.customDuration != null
            ? track.customDuration!
            : track.totalDuration.toDouble();
        return sum + duration;
      });
  TransitionPlaybackState get currentTransitionState => _currentTransitionState;

  // Audio mute state getters
  bool isVideoMuted(String videoId) => _videoMuteStates[videoId] ?? false;
  bool isAudioMuted(String audioId) => _audioMuteStates[audioId] ?? false;

  /// Initialize with video tracks and controllers
  void initialize({
    required List<VideoTrackModel> tracks,
    required Map<String, VideoEditorController> controllers,
    List<AudioTrackModel>? audioTracks,
    Map<String, PlayerController>? audioControllers,
    bool preservePosition =
        false, // Add parameter to preserve timeline position
  }) {
    if (_isDisposed) return;

    // Preserve current timeline position if requested (for track updates during drag)
    final savedPosition = preservePosition ? _currentTimelinePosition : 0.0;

    _videoTracks.clear();
    _videoTracks.addAll(tracks);
    _videoControllers.clear();
    _videoControllers.addAll(controllers);

    // Log transition configuration for debugging
    print('🎬 MasterTimelineController initialized with ${_videoTracks.length} tracks:');
    for (int i = 0; i < _videoTracks.length; i++) {
      final track = _videoTracks[i];
      final hasTransition = track.transitionToNext != null && track.transitionToNext != TransitionType.none;
      if (hasTransition) {
        print('   Track $i → Track ${i + 1}: ${track.transitionToNext!.name} (${track.transitionToNextDuration}s)');
      } else {
        print('   Track $i: No transition');
      }
    }

    // Initialize audio tracks and controllers
    _audioTracks.clear();
    if (audioTracks != null) {
      _audioTracks.addAll(audioTracks);
    }
    _audioControllers.clear();
    if (audioControllers != null) {
      _audioControllers.addAll(audioControllers);
    }

    // Clear disposal tracking
    _disposedControllerIds.clear();
    _pendingDisposalIds.clear();
    _disposedAudioControllerIds.clear();

    // Reset to beginning or preserve position
    _currentTimelinePosition = savedPosition;
    _currentTrackId = null;

    // Ensure all individual controllers are paused initially
    for (var entry in _videoControllers.entries) {
      _safeControllerAction(entry.key, (controller) {
        if (controller.video.value.isInitialized &&
            controller.video.value.isPlaying) {
          controller.video.pause();
        }
      });
    }
  }

  /// Get current video track and position within it
  (VideoTrackModel?, double) getCurrentVideoAndPosition() {
    for (var track in _videoTracks) {
      if (_currentTimelinePosition >= track.startTime.toDouble() &&
          _currentTimelinePosition < track.endTime.toDouble()) {
        double positionInVideo =
            _currentTimelinePosition - track.startTime.toDouble();
        return (track, positionInVideo);
      }
    }

    // Handle edge case: if we're at the exact end of timeline, return last video
    if (_currentTimelinePosition >= totalDuration && _videoTracks.isNotEmpty) {
      final lastTrack = _videoTracks.last;
      // Calculate position at the end of the last video
      final videoEndTime = lastTrack.videoTrimEnd > 0
          ? lastTrack.videoTrimEnd
          : lastTrack.originalDuration;
      // Return position just before the end to show the last frame
      return (lastTrack, (videoEndTime - 0.033).clamp(0.0, videoEndTime));
    }

    return (null, 0.0);
  }

/// Get current transition state including start and end transitions
TransitionPlaybackState getCurrentTransitionState() {
  if (_videoTracks.isEmpty) return TransitionPlaybackState.none();

  final firstTrack = _videoTracks.first;
  final lastTrack = _videoTracks.last;

  //----------------------------------------------------------------------
  // 1. START TRANSITION (Before first video fully appears)
  //----------------------------------------------------------------------
  if (firstTrack.transitionFromStart != null &&
      firstTrack.transitionFromStart != TransitionType.none) {

    final duration = firstTrack.transitionFromStartDuration ?? 1.0;

    if (_currentTimelinePosition >= 0.0 &&
        _currentTimelinePosition < duration) {

      final progress = (_currentTimelinePosition / duration).clamp(0.0, 1.0);

      return TransitionPlaybackState(
        isInTransition: true,
        transitionType: firstTrack.transitionFromStart,
        progress: progress,
        fromTrackIndex: -1,  // "start"
        toTrackIndex: 0,
        transitionDuration: duration,
      );
    }
  }

  //----------------------------------------------------------------------
  // 2. MIDDLE TRANSITIONS (existing logic)
  //----------------------------------------------------------------------
  double cumulativeTime = 0.0;

  for (int i = 0; i < _videoTracks.length - 1; i++) {
    final currentTrack = _videoTracks[i];
    final trackEndTime = cumulativeTime + currentTrack.totalDuration;

    if (currentTrack.transitionToNext != null &&
        currentTrack.transitionToNext != TransitionType.none) {

      final duration = currentTrack.transitionToNextDuration;

      final start = trackEndTime - duration;
      final end = trackEndTime;

      if (_currentTimelinePosition >= start &&
          _currentTimelinePosition < end) {

        final progress =
            ((_currentTimelinePosition - start) / duration).clamp(0.0, 1.0);

        return TransitionPlaybackState(
          isInTransition: true,
          transitionType: currentTrack.transitionToNext,
          progress: progress,
          fromTrackIndex: i,
          toTrackIndex: i + 1,
          transitionDuration: duration,
        );
      }
    }

    cumulativeTime += currentTrack.totalDuration;
  }

  //----------------------------------------------------------------------
  // 3. END TRANSITION (Fade-out at end of last track)
  //----------------------------------------------------------------------
  if (lastTrack.transitionToEnd != null &&
      lastTrack.transitionToEnd != TransitionType.none) {

    final duration = lastTrack.transitionToEndDuration ?? 1.0;
    final videoEnd = totalDuration;
    final start = videoEnd - duration;

    if (_currentTimelinePosition >= start &&
        _currentTimelinePosition <= videoEnd) {

      final progress =
          ((_currentTimelinePosition - start) / duration).clamp(0.0, 1.0);

      return TransitionPlaybackState(
        isInTransition: true,
        transitionType: lastTrack.transitionToEnd,
        progress: progress,
        fromTrackIndex: _videoTracks.length - 1,
        toTrackIndex: -1, // end
        transitionDuration: duration,
      );
    }
  }

  return TransitionPlaybackState.none();
}



  /// Update cached transition state (called during playback)
  void _updateTransitionState() {
    final newState = getCurrentTransitionState();

    // Only log when transition state changes
    if (_currentTransitionState.isInTransition != newState.isInTransition ||
        _currentTransitionState.transitionType != newState.transitionType) {
      if (newState.isInTransition) {
        print('🎬 Entering transition: ${newState.transitionType?.name} (track ${newState.fromTrackIndex} → ${newState.toTrackIndex})');
      } else if (_currentTransitionState.isInTransition) {
        print('✅ Exiting transition');
      }
    }

    _currentTransitionState = newState;
  }

  /// Seek to specific timeline position from scroll with debouncing
  void seekFromScroll(double scrollOffset, double maxScrollExtent) {
    if (maxScrollExtent <= 0) return;

    // Cancel any pending seek
    _seekDebounceTimer?.cancel();
    _isSeeking = true;

    // Pause during seeking if playing
    bool wasPlaying = _isPlaying;
    if (_isPlaying) {
      pause();
    }

    // Update position immediately for UI feedback
    double progress = (scrollOffset / maxScrollExtent).clamp(0.0, 1.0);
    _currentTimelinePosition =
        (totalDuration * progress).clamp(0.0, totalDuration);
    _updateTransitionState(); // Update transition state for UI feedback
    onPositionChanged?.call();

    // Debounce the actual video seek
    _seekDebounceTimer = Timer(const Duration(milliseconds: 50), () {
      _updateCurrentVideo(seekOnly: true);
      _updateAudioTracks(); // Update audio tracks after seeking
      _isSeeking = false;

      // Resume if was playing before
      if (wasPlaying) {
        play();
      }

      onPositionChanged?.call();
    });
  }

  /// Seek to specific time in seconds
  void seekToTime(double seconds) {
    bool wasPlaying = _isPlaying;
    pause(); // Pause during seeking

    _currentTimelinePosition = seconds.clamp(0.0, totalDuration);
    _updateTransitionState(); // Update transition state after seeking

    // Ensure we seek the correct video immediately
    _updateCurrentVideo(seekOnly: true);
    _updateAudioTracks(); // Update audio tracks after seeking

    // If we were playing, resume playback from new position
    if (wasPlaying) {
      play();
    }

    onPositionChanged?.call();
  }

  /// Start playback
  void play() {
    if (_isDisposed || _isPlaying) return;

    _isPlaying = true;

    // Cancel any existing timers
    _playbackTimer?.cancel();
    _positionUpdateTimer?.cancel();

    // Update current video immediately
    _updateCurrentVideo();

    // Get starting timestamp
    final startTime = DateTime.now();
    final initialPosition = _currentTimelinePosition;

    // Create a canvas-style playback timer using pure elapsed time calculation
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      if (_isDisposed || !_isPlaying) {
        timer.cancel();
        return;
      }

      // Calculate elapsed time since playback started (canvas-style approach)
      final elapsed =
          DateTime.now().difference(startTime).inMilliseconds / 1000.0;
      final newPosition = initialPosition + elapsed;

      // Check if we've reached the end
      if (newPosition >= totalDuration) {
        _currentTimelinePosition = totalDuration;
        pause();
        onPositionChanged?.call();
        return;
      }

      // Canvas-style: Always update position based on elapsed time, not video controller
      _currentTimelinePosition = newPosition;

      // Update transition state every frame for smooth animations
      _updateTransitionState();

      // Update current video and handle transitions
      if (timer.tick % 2 == 0) {
        // Update every 2nd frame (~66ms) for more responsive audio control
        _updateCurrentVideo();
        _updateAudioTracks();
      }

      onPositionChanged?.call();
    });

    onPlayStateChanged?.call();
  }

  /// Pause playback
  void pause() {
    if (_isDisposed || !_isPlaying) return;

    _isPlaying = false;
    _playbackTimer?.cancel();
    _positionUpdateTimer?.cancel();

    // Pause all video controllers
    for (var entry in _videoControllers.entries) {
      _safeControllerAction(entry.key, (controller) {
        if (controller.video.value.isInitialized &&
            controller.video.value.isPlaying) {
          controller.video.pause();
        }
      });
    }

    // Pause all audio controllers
    for (var entry in _audioControllers.entries) {
      final controller = entry.value;
      if (controller.playerState.isPlaying) {
        controller.pausePlayer();
      }
    }

    onPlayStateChanged?.call();
  }

  /// Toggle play/pause
  void togglePlayPause() {
    if (_isPlaying) {
      pause();
    } else {
      play();
    }
  }

  /// Audio and video mute control methods
  void toggleVideoMute(String videoId) {
    _videoMuteStates[videoId] = !(_videoMuteStates[videoId] ?? false);

    // Apply mute state to current video if it's playing
    _applyVideoMuteState(videoId);
  }

  void toggleAudioMute(String audioId) {
    _audioMuteStates[audioId] = !(_audioMuteStates[audioId] ?? false);

    // Apply mute state to audio controller if it exists
    final controller = _audioControllers[audioId];
    if (controller != null) {
      final isMuted = _audioMuteStates[audioId] ?? false;
      controller.setVolume(isMuted ? 0.0 : 1.0);
    }

    // Force immediate update of all audio tracks during playback
    if (_isPlaying) {
      _updateAudioTracks();
    }
  }

  void _applyVideoMuteState(String videoId) {
    final controller = _videoControllers[videoId];
    if (controller != null) {
      final isMuted = _videoMuteStates[videoId] ?? false;
      _safeControllerAction(videoId, (controller) {
        controller.video.setVolume(isMuted ? 0.0 : 1.0);
      });
    }
  }

  /// Get active audio tracks at current timeline position
  List<AudioTrackModel> getActiveAudioTracks() {
    return _audioTracks.where((track) {
      final startTime = track.trimStartTime;
      final endTime =
          track.trimEndTime > 0 ? track.trimEndTime : track.totalDuration;
      return _currentTimelinePosition >= startTime &&
          _currentTimelinePosition < endTime;
    }).toList();
  }

  /// Update audio track playback based on timeline position
  void _updateAudioTracks() {
    if (_isDisposed) return;

    final activeAudioTracks = getActiveAudioTracks();

    // Stop inactive audio tracks
    for (var entry in _audioControllers.entries) {
      final audioId = entry.key;
      final controller = entry.value;

      final isActive = activeAudioTracks.any((track) => track.id == audioId);

      if (!isActive && controller.playerState.isPlaying) {
        controller.pausePlayer();
      }
    }

    // Start or sync active audio tracks
    for (var track in activeAudioTracks) {
      final controller = _audioControllers[track.id];
      if (controller == null) continue;

      final positionInAudio = _currentTimelinePosition - track.trimStartTime;
      final targetPositionMs = (positionInAudio * 1000).round();

      // Apply mute state
      final isMuted = _audioMuteStates[track.id] ?? false;
      controller.setVolume(isMuted ? 0.0 : 1.0);

      if (_isPlaying && !controller.playerState.isPlaying) {
        // Start playback
        controller.seekTo(targetPositionMs);
        controller.startPlayer();
      } else if (!_isPlaying && controller.playerState.isPlaying) {
        // Pause playback
        controller.pausePlayer();
      } else if (_isPlaying && controller.playerState.isPlaying) {
        // Sync position if needed (less frequently to reduce overhead)
        // Only sync if position is significantly off
        // This will be handled by the periodic sync in the play method
      }
    }
  }

  /// Safe wrapper for controller actions that checks disposal state
  void _safeControllerAction(
      String controllerId, Function(VideoEditorController) action) {
    if (_isDisposed) return;

    // Don't block action if controller is pending disposal but currently active
    if (_disposedControllerIds.contains(controllerId)) {
      print('⚠️ Skipping action on disposed controller $controllerId');
      return;
    }

    final controller = _videoControllers[controllerId];
    if (controller == null) {
      print('⚠️ Controller not found for $controllerId');
      return;
    }

    // Check if controller is properly initialized
    if (!controller.video.value.isInitialized) {
      print('⚠️ Controller not initialized for $controllerId');
      return;
    }

    try {
      action(controller);
    } catch (e) {
      // Only mark as disposed if it's a disposal-related error
      if (e.toString().contains('disposed') ||
          e.toString().contains('unmounted')) {
        _disposedControllerIds.add(controllerId);
        print('⚠️ Controller disposed error for $controllerId: $e');
      } else {
        print('⚠️ Controller error for $controllerId: $e');
      }
    }
  }

  /// Update current video based on timeline position
  void _updateCurrentVideo({bool seekOnly = false}) {
    if (_isDisposed) return;

    // Skip if we're in the middle of seeking
    if (_isSeeking && !seekOnly) return;

    var (currentTrack, positionInVideo) = getCurrentVideoAndPosition();

    if (currentTrack == null) {
      // No video at current position - check if we're at the end
      if (_currentTimelinePosition >= totalDuration &&
          _videoTracks.isNotEmpty) {
        // We've reached the end - use the last track and seek to its final frame
        final lastTrack = _videoTracks.last;
        _currentTrackId = lastTrack.id;

        _safeControllerAction(lastTrack.id, (controller) {
          // Calculate the actual end position within the video considering trim
          final videoEndTime = lastTrack.videoTrimEnd > 0
              ? lastTrack.videoTrimEnd
              : lastTrack.originalDuration;
          // Seek to just before the very end to ensure we get a valid frame (30fps = 33ms per frame)
          final lastFramePosition = Duration(
              milliseconds: ((videoEndTime * 1000) - 33)
                  .round()
                  .clamp(0, (videoEndTime * 1000).round()));

          controller.video.seekTo(lastFramePosition);
          if (controller.video.value.isPlaying) {
            controller.video.pause();
          }
        });

        // Pause all other controllers
        for (var entry in _videoControllers.entries) {
          if (entry.key != lastTrack.id) {
            _safeControllerAction(entry.key, (controller) {
              if (controller.video.value.isPlaying) {
                controller.video.pause();
              }
            });
          }
        }
        return;
      }

      // Try to find the next video if we're between videos
      VideoTrackModel? nextTrack;
      for (var track in _videoTracks) {
        if (_currentTimelinePosition < track.startTime.toDouble()) {
          nextTrack = track;
          break;
        }
      }

      if (nextTrack != null) {
        // Jump to next video's start
        _currentTimelinePosition = nextTrack.startTime.toDouble();
        currentTrack = nextTrack;
        positionInVideo = 0.0;
      } else {
        return;
      }
    }

    // At this point currentTrack is guaranteed to be non-null
    final currentTrackId = currentTrack.id;

    // Check if we've switched to a different video - remove aggressive debouncing
    bool trackChanged = _currentTrackId != currentTrackId;

    // Get controller for current track - reactivate if needed
    if (_disposedControllerIds.contains(currentTrackId)) {
      print('🔄 Reactivating controller for $currentTrackId');
      _disposedControllerIds.remove(currentTrackId);
    }
    if (_pendingDisposalIds.contains(currentTrackId)) {
      print('🔄 Canceling pending disposal for $currentTrackId');
      _pendingDisposalIds.remove(currentTrackId);
    }

    var controller = _videoControllers[currentTrackId];
    if (controller == null || !controller.video.value.isInitialized) {
      print(
          '🔄 Controller missing/uninitialized for $currentTrackId, requesting recreation');

      // Trigger recreation via callback
      if (onRecreateController != null) {
        onRecreateController!(currentTrackId);
      }
      return; // Will be called again once controller is ready
    }

    // Find current track index to determine next video for preloading
    final currentIndex = _videoTracks.indexWhere((t) => t.id == currentTrackId);
    final nextTrackId =
        (currentIndex >= 0 && currentIndex < _videoTracks.length - 1)
            ? _videoTracks[currentIndex + 1].id
            : null;

    // If track changed, handle video transition
    if (trackChanged) {
      // Update active controllers list - keep 2 previous + current + 2 next
      _activeControllerIds.clear();
      _activeControllerIds.add(currentTrackId);

      // Keep 2 next video controllers
      final nextControllerIds = <String>[];
      for (int offset = 1; offset <= 2; offset++) {
        final nextIndex = currentIndex + offset;
        if (nextIndex < _videoTracks.length) {
          final nextId = _videoTracks[nextIndex].id;
          _activeControllerIds.add(nextId);
          nextControllerIds.add(nextId);
        }
      }

      // Keep 2 previous video controllers
      final prevControllerIds = <String>[];
      for (int offset = 1; offset <= 2; offset++) {
        final prevIndex = currentIndex - offset;
        if (prevIndex >= 0) {
          final prevId = _videoTracks[prevIndex].id;
          _activeControllerIds.add(prevId);
          prevControllerIds.add(prevId);
        }
      }

      print('🎯 Active controllers: ${_activeControllerIds.length} total');
      print('   Current: $currentTrackId');
      print('   Previous: $prevControllerIds');
      print('   Next: $nextControllerIds');

      // Trigger preloading for missing controllers
      for (final activeId in _activeControllerIds) {
        final activeController = _videoControllers[activeId];
        if (activeController == null ||
            !activeController.video.value.isInitialized) {
          print('🔄 Preloading missing controller: $activeId');
          onRecreateController?.call(activeId);
        }
      }

      // Only mark controllers for disposal if they're not in the keep list
      final controllersToMark = <String>[];
      for (var entry in _videoControllers.entries) {
        if (!_activeControllerIds.contains(entry.key) &&
            !_pendingDisposalIds.contains(entry.key)) {
          controllersToMark.add(entry.key);
        }
      }

      // Only add new controllers to pending disposal
      _pendingDisposalIds.addAll(controllersToMark);

      // Pause inactive controllers safely
      for (var entry in _videoControllers.entries) {
        if (!_activeControllerIds.contains(entry.key)) {
          _safeControllerAction(entry.key, (controller) {
            if (controller.video.value.isPlaying) {
              controller.video.pause();
              print('⏸️ Paused video: ${entry.key}');
            }
          });
        }
      }

      // Smart disposal timing with distance checks
      Timer(const Duration(milliseconds: 8000), () {
        if (_isDisposed) return;

        // Only dispose controllers that are still pending and not reactivated
        final controllersToDispose =
            _pendingDisposalIds.difference(_activeControllerIds);

        // Additional safety check: don't dispose controllers close to current position
        final currentTime = _currentTimelinePosition;
        final safeToDisposeIds = <String>{};

        for (final controllerId in controllersToDispose) {
          try {
            final track = _videoTracks.firstWhere((t) => t.id == controllerId);
            final distanceFromCurrent = (track.startTime - currentTime).abs();
            if (distanceFromCurrent > 15.0) {
              // 15 seconds buffer
              safeToDisposeIds.add(controllerId);
            } else {
              print(
                  '🛡️ Keeping $controllerId - too close to current position (${distanceFromCurrent.toStringAsFixed(1)}s away)');
            }
          } catch (e) {
            // If track not found, it's safe to dispose
            safeToDisposeIds.add(controllerId);
          }
        }

        if (safeToDisposeIds.isNotEmpty) {
          print('🗑️ Smart disposing controllers: $safeToDisposeIds');
          _disposedControllerIds.addAll(safeToDisposeIds);

          if (onDisposeUnusedControllers != null) {
            final keepIds = _activeControllerIds.toList();
            onDisposeUnusedControllers!(keepIds);
          }
        }

        _pendingDisposalIds.clear();
      });

      print(
          '🔄 Transitioning from ${_currentTrackId ?? 'none'} to $currentTrackId');
      if (nextTrackId != null) {
        print('📋 Next video ready: $nextTrackId');
      }
    }

    _currentTrackId = currentTrackId;

    // Calculate target position accounting for video trim bounds
    // positionInVideo is relative to the timeline, but we need to map it to the trimmed video
    final trimmedPositionInVideo =
        positionInVideo + currentTrack.videoTrimStart;
    final targetPositionMs = (trimmedPositionInVideo * 1000).round();
    final targetPosition = Duration(milliseconds: targetPositionMs);

    // Safe seek operation
    _safeControllerAction(currentTrackId, (controller) {
      final currentPosition = controller.video.value.position;
      final positionDiff =
          (targetPosition.inMilliseconds - currentPosition.inMilliseconds)
              .abs();

      // Improved tolerance for short videos - be more aggressive with sync for videos < 5 seconds
      final videoDuration = controller.video.value.duration.inMilliseconds;
      final isShortVideo = videoDuration < 5000;
      final tolerance = seekOnly ? 50 : (isShortVideo ? 200 : 500);

      // Only sync during transitions or if position is significantly off
      if (positionDiff > tolerance || trackChanged) {
        controller.video.seekTo(targetPosition);
        if (trackChanged || seekOnly || positionDiff > tolerance) {
          print(
              '🎯 Seeking $currentTrackId to ${targetPosition.inSeconds}s (track changed: $trackChanged, diff: ${positionDiff}ms)');
        }
      }

      // Apply video mute state
      _applyVideoMuteState(currentTrackId);
    });

    // Enhanced play state management for seamless transitions
    if (!seekOnly && _isPlaying) {
      _safeControllerAction(currentTrackId, (controller) {
        if (!controller.video.value.isPlaying) {
          // Pre-warm next video controller if available
          if (nextTrackId != null &&
              !trackChanged &&
              !_disposedControllerIds.contains(nextTrackId)) {
            final nextController = _videoControllers[nextTrackId];
            if (nextController != null &&
                nextController.video.value.isInitialized) {
              try {
                nextController.video.seekTo(Duration.zero);
              } catch (e) {
                // Mark as problematic if seeking fails
                _disposedControllerIds.add(nextTrackId);
              }
            }
          }

          controller.video.play();
          print('▶️ Playing video: $currentTrackId');
        }
      });
    } else if ((seekOnly || !_isPlaying)) {
      _safeControllerAction(currentTrackId, (controller) {
        if (controller.video.value.isPlaying) {
          controller.video.pause();
          print('⏸️ Paused video: $currentTrackId');
        }
      });
    }

    // Always notify listeners when seeking or track changes
    if (seekOnly || trackChanged) {
      onPositionChanged?.call();
    }
  }

  /// Get scroll offset for current timeline position
  double getScrollOffset(double maxScrollExtent) {
    if (totalDuration <= 0) return 0.0;
    double progress = _currentTimelinePosition / totalDuration;
    return (maxScrollExtent * progress).clamp(0.0, maxScrollExtent);
  }

  /// Dispose of resources
  void dispose() {
    _isDisposed = true;

    _playbackTimer?.cancel();
    _positionUpdateTimer?.cancel();
    _seekDebounceTimer?.cancel();

    // Pause all videos safely
    for (var entry in _videoControllers.entries) {
      _safeControllerAction(entry.key, (controller) {
        if (controller.video.value.isPlaying) {
          controller.video.pause();
        }
      });
    }

    // Pause and dispose all audio controllers safely
    for (var entry in _audioControllers.entries) {
      final controller = entry.value;
      try {
        if (controller.playerState.isPlaying) {
          controller.pausePlayer();
        }
        controller.dispose();
      } catch (e) {
        print('⚠️ Error disposing audio controller ${entry.key}: $e');
      }
    }

    // Clear all tracking sets
    _activeControllerIds.clear();
    _disposedControllerIds.clear();
    _pendingDisposalIds.clear();
    _activeAudioControllerIds.clear();
    _disposedAudioControllerIds.clear();

    // Clear audio controllers and mute states
    _audioControllers.clear();
    _videoMuteStates.clear();
    _audioMuteStates.clear();
  }
}
