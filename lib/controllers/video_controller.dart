import 'dart:io';

import 'package:ai_video_creator_editor/screens/project/models/crop_style.dart';
import 'package:ai_video_creator_editor/utils/helpers.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

enum RotateDirection { left, right }

const Offset maxOffset = Offset(1.0, 1.0);

const Offset minOffset = Offset.zero;

class VideoEditorController extends ChangeNotifier {
  final CropGridStyle cropStyle;

  final File file;

  VideoEditorController.file(
    this.file, {
    this.cropStyle = const CropGridStyle(),
  }) : _video = VideoPlayerController.file(File(
          Platform.isIOS ? Uri.encodeFull(file.path) : file.path,
        ));

  int _rotation = 0;
  bool isCropping = false;

  double? _preferredCropAspectRatio;

  Offset _minCrop = minOffset;
  Offset _maxCrop = maxOffset;

  Offset cacheMinCrop = minOffset;
  Offset cacheMaxCrop = maxOffset;

  final VideoPlayerController _video;

  VideoPlayerController get video => _video;

  bool get initialized => _video.value.isInitialized;

  bool get isPlaying => _video.value.isPlaying;

  Duration get videoPosition => _video.value.position;

  Duration get videoDuration => _video.value.duration;

  Size get videoDimension => _video.value.size;
  double get videoWidth => videoDimension.width;
  double get videoHeight => videoDimension.height;

  Offset get minCrop => _minCrop;

  Offset get maxCrop => _maxCrop;

  Size get croppedArea => Rect.fromLTWH(
        0,
        0,
        videoWidth * (maxCrop.dx - minCrop.dx),
        videoHeight * (maxCrop.dy - minCrop.dy),
      ).size;

  double? get preferredCropAspectRatio => _preferredCropAspectRatio;
  set preferredCropAspectRatio(double? value) {
    if (preferredCropAspectRatio == value) return;
    _preferredCropAspectRatio = value;
    notifyListeners();
  }

  Rect get cropRect {
    final left = minCrop.dx * videoWidth;
    final top = minCrop.dy * videoHeight;
    final right = maxCrop.dx * videoWidth;
    final bottom = maxCrop.dy * videoHeight;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  void cropAspectRatio(double? value) {
    preferredCropAspectRatio = value;

    if (value != null) {
      final newSize = computeSizeWithRatio(videoDimension, value);

      Rect centerCrop = Rect.fromCenter(
        center: Offset(videoWidth / 2, videoHeight / 2),
        width: newSize.width,
        height: newSize.height,
      );

      _minCrop =
          Offset(centerCrop.left / videoWidth, centerCrop.top / videoHeight);
      _maxCrop = Offset(
          centerCrop.right / videoWidth, centerCrop.bottom / videoHeight);
      notifyListeners();
    }
  }

  Future<void> initialize({double? aspectRatio}) async {
    await _video.initialize();
    cropAspectRatio(aspectRatio);
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    if (_video.value.isPlaying) await _video.pause();
    _video.dispose();
    super.dispose();
  }

  void applyCacheCrop() => updateCrop(cacheMinCrop, cacheMaxCrop);

  void updateCrop(Offset min, Offset max) {
    assert(min < max,
        'Minimum crop value ($min) cannot be bigger and maximum crop value ($max)');

    _minCrop = min;
    _maxCrop = max;
    notifyListeners();
  }

  int get cacheRotation => _rotation;

  int get rotation => (_rotation ~/ 90 % 4) * 90;

  void rotate90Degrees([RotateDirection direction = RotateDirection.right]) {
    switch (direction) {
      case RotateDirection.left:
        _rotation -= 90; // LEFT = counter-clockwise (corrected!)
        break;
      case RotateDirection.right:
        _rotation += 90; // RIGHT = clockwise (corrected!)
        break;
    }

    // Normalize rotation to prevent accumulation of large values
    // This prevents unwanted animations when the same rotation is applied multiple times
    _rotation = _rotation % 360;

    notifyListeners();
  }

  bool get isRotated => rotation == 90 || rotation == 270;
}
