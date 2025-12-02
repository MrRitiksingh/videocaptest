import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:ai_video_creator_editor/components/crop/crop_grid.dart';
import 'package:ai_video_creator_editor/controllers/video_controller.dart';
import 'package:ai_video_creator_editor/screens/project/models/video_track_model.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/video_editor_provider.dart';
import 'video_canvas_item.dart';

/// Dialog for cropping individual videos in multi-video canvas mode
class IndividualVideoCropDialog extends StatefulWidget {
  final VideoEditorProvider provider;
  final VideoCanvasItem videoItem;
  final String videoTrackId;

  const IndividualVideoCropDialog({
    super.key,
    required this.provider,
    required this.videoItem,
    required this.videoTrackId,
  });

  @override
  State<IndividualVideoCropDialog> createState() => _IndividualVideoCropDialogState();
}

class _IndividualVideoCropDialogState extends State<IndividualVideoCropDialog> {
  late Rect _cropRect;
  late VideoEditorController _controller;
  bool _isPreviewMode = false;

  @override
  void initState() {
    super.initState();
    _cropRect = widget.videoItem.cropRect;
    _controller = widget.videoItem.controller;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Crop Video',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isPreviewMode ? Icons.edit : Icons.preview,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPreviewMode = !_isPreviewMode;
                        });
                      },
                      tooltip: _isPreviewMode ? 'Edit Mode' : 'Preview Mode',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Video preview with crop controls
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _isPreviewMode
                      ? _buildPreviewMode()
                      : _buildCropMode(),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Crop controls
            if (!_isPreviewMode) _buildCropControls(),
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _resetCrop,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                  ),
                  child: const Text(
                    'Reset',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                ElevatedButton(
                  onPressed: _applyCrop,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                  child: const Text(
                    'Apply',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCropMode() {
    return CropGridViewer.edit(
      controller: _controller,
      margin: const EdgeInsets.all(8),
    );
  }

  Widget _buildPreviewMode() {
    return Stack(
      children: [
        // Video with current crop applied
        Center(
          child: AspectRatio(
            aspectRatio: _controller.video.value.aspectRatio,
            child: ClipRect(
              clipper: _cropRect != const Rect.fromLTWH(0, 0, 1, 1)
                  ? _VideoCropClipper(_cropRect)
                  : null,
              child: VideoPlayer(_controller.video),
            ),
          ),
        ),
        
        // Crop info overlay
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Crop: ${(_cropRect.width * 100).toStringAsFixed(1)}% × ${(_cropRect.height * 100).toStringAsFixed(1)}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCropControls() {
    return Column(
      children: [
        // Aspect ratio presets
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildAspectRatioButton('Free', null),
            _buildAspectRatioButton('1:1', 1.0),
            _buildAspectRatioButton('4:3', 4.0 / 3.0),
            _buildAspectRatioButton('16:9', 16.0 / 9.0),
            _buildAspectRatioButton('9:16', 9.0 / 16.0),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Crop position controls
        Row(
          children: [
            const Text(
              'Position:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCropPositionButton('↖', () => _setCropPosition(Alignment.topLeft)),
                  _buildCropPositionButton('↑', () => _setCropPosition(Alignment.topCenter)),
                  _buildCropPositionButton('↗', () => _setCropPosition(Alignment.topRight)),
                  _buildCropPositionButton('←', () => _setCropPosition(Alignment.centerLeft)),
                  _buildCropPositionButton('●', () => _setCropPosition(Alignment.center)),
                  _buildCropPositionButton('→', () => _setCropPosition(Alignment.centerRight)),
                  _buildCropPositionButton('↙', () => _setCropPosition(Alignment.bottomLeft)),
                  _buildCropPositionButton('↓', () => _setCropPosition(Alignment.bottomCenter)),
                  _buildCropPositionButton('↘', () => _setCropPosition(Alignment.bottomRight)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAspectRatioButton(String label, double? aspectRatio) {
    return InkWell(
      onTap: () => _setAspectRatio(aspectRatio),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _controller.preferredCropAspectRatio == aspectRatio
              ? Colors.blue
              : Colors.grey[800],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCropPositionButton(String symbol, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey[600]!),
        ),
        child: Center(
          child: Text(
            symbol,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  void _setAspectRatio(double? aspectRatio) {
    setState(() {
      _controller.preferredCropAspectRatio = aspectRatio;
    });
  }

  void _setCropPosition(Alignment alignment) {
    final videoSize = _controller.video.value.size;
    final aspectRatio = _controller.preferredCropAspectRatio ?? (videoSize.width / videoSize.height);
    
    // Calculate crop dimensions
    double cropWidth = 1.0;
    double cropHeight = 1.0;
    
    if (_controller.preferredCropAspectRatio != null) {
      final videoAspectRatio = videoSize.width / videoSize.height;
      
      if (aspectRatio > videoAspectRatio) {
        // Crop is wider than video - limit by width
        cropWidth = 1.0;
        cropHeight = videoAspectRatio / aspectRatio;
      } else {
        // Crop is taller than video - limit by height
        cropHeight = 1.0;
        cropWidth = aspectRatio / videoAspectRatio;
      }
    }
    
    // Calculate position based on alignment
    double left = 0.0;
    double top = 0.0;
    
    switch (alignment) {
      case Alignment.topLeft:
        left = 0.0;
        top = 0.0;
        break;
      case Alignment.topCenter:
        left = (1.0 - cropWidth) / 2;
        top = 0.0;
        break;
      case Alignment.topRight:
        left = 1.0 - cropWidth;
        top = 0.0;
        break;
      case Alignment.centerLeft:
        left = 0.0;
        top = (1.0 - cropHeight) / 2;
        break;
      case Alignment.center:
        left = (1.0 - cropWidth) / 2;
        top = (1.0 - cropHeight) / 2;
        break;
      case Alignment.centerRight:
        left = 1.0 - cropWidth;
        top = (1.0 - cropHeight) / 2;
        break;
      case Alignment.bottomLeft:
        left = 0.0;
        top = 1.0 - cropHeight;
        break;
      case Alignment.bottomCenter:
        left = (1.0 - cropWidth) / 2;
        top = 1.0 - cropHeight;
        break;
      case Alignment.bottomRight:
        left = 1.0 - cropWidth;
        top = 1.0 - cropHeight;
        break;
      default:
        left = (1.0 - cropWidth) / 2;
        top = (1.0 - cropHeight) / 2;
    }
    
    setState(() {
      _cropRect = Rect.fromLTWH(left, top, cropWidth, cropHeight);
      _controller.updateCrop(Offset(left, top), Offset(left + cropWidth, top + cropHeight));
      print('🔄 Crop position updated: left=${left.toStringAsFixed(4)}, '
            'top=${top.toStringAsFixed(4)}, '
            'width=${cropWidth.toStringAsFixed(4)}, '
            'height=${cropHeight.toStringAsFixed(4)}');
    });
  }

  void _resetCrop() {
    setState(() {
      _cropRect = const Rect.fromLTWH(0, 0, 1, 1);
      _controller.updateCrop(Offset.zero, const Offset(1, 1));
      _controller.preferredCropAspectRatio = null;
    });
  }

  void _applyCrop() {
    print('🎯 Applying crop to video track: ${widget.videoTrackId}');
    print('📐 Crop rect values: left=${_cropRect.left.toStringAsFixed(4)}, '
          'top=${_cropRect.top.toStringAsFixed(4)}, '
          'width=${_cropRect.width.toStringAsFixed(4)}, '
          'height=${_cropRect.height.toStringAsFixed(4)}');
    
    // Update the video item's crop rectangle
    widget.videoItem.updateCrop(_cropRect);
    
    // Update the provider with the new crop settings
    widget.provider.updateVideoTrackCanvasProperties(
      widget.videoTrackId,
      cropRect: _cropRect,
    );
    
    Navigator.pop(context, true);
  }
}

/// Custom clipper for video crop preview
class _VideoCropClipper extends CustomClipper<Rect> {
  final Rect cropRect;
  
  _VideoCropClipper(this.cropRect);
  
  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(
      cropRect.left * size.width,
      cropRect.top * size.height,
      cropRect.width * size.width,
      cropRect.height * size.height,
    );
  }
  
  @override
  bool shouldReclip(_VideoCropClipper oldClipper) {
    return oldClipper.cropRect != cropRect;
  }
}

/// Helper to show the individual video crop dialog
class IndividualVideoCropHelper {
  static Future<bool?> showCropDialog(
    BuildContext context,
    VideoEditorProvider provider,
    VideoCanvasItem videoItem,
    String videoTrackId,
  ) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => IndividualVideoCropDialog(
        provider: provider,
        videoItem: videoItem,
        videoTrackId: videoTrackId,
      ),
    );
  }
}