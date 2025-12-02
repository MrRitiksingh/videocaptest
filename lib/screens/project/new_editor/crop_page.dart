import 'package:provider/provider.dart';
import 'package:ai_video_creator_editor/components/crop/crop_grid.dart';
import 'package:ai_video_creator_editor/controllers/video_controller.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/video_editor_provider.dart';

import 'package:flutter/material.dart';
import 'package:fraction/fraction.dart';

class CropPage extends StatefulWidget {
  const CropPage({super.key, required this.controller, this.initialRotation});

  final VideoEditorController controller;
  final int? initialRotation;

  @override
  State<CropPage> createState() => _CropPageState();
}

class _CropPageState extends State<CropPage> {
  int _rotation = 0;

  @override
  void initState() {
    super.initState();
    // Initialize rotation from track rotation (passed as parameter), not controller
    // This ensures we maintain the actual track state, not the controller's internal state
    _rotation = widget.initialRotation ?? 0;
    
    print('🎯 CropPage opened with initial rotation: ${widget.initialRotation}°');
    
    // CRITICAL: Set controller to match track rotation state
    _initializeControllerRotation();
  }

  void _initializeControllerRotation() {
    final targetRotation = _rotation;
    final currentControllerRotation = widget.controller.rotation;
    
    print('🔄 Initializing controller rotation:');
    print('   Target rotation (from track): $targetRotation°');
    print('   Current controller rotation: $currentControllerRotation°');
    
    if (targetRotation != currentControllerRotation) {
      final rotationDiff = (targetRotation - currentControllerRotation) ~/ 90;
      
      print('   Rotation difference: $rotationDiff steps (${rotationDiff * 90}°)');
      
      for (int i = 0; i < rotationDiff.abs(); i++) {
        if (rotationDiff > 0) {
          // Need to rotate clockwise → Use RIGHT (correct direction)
          widget.controller.rotate90Degrees(RotateDirection.right);
        } else {
          // Need to rotate counter-clockwise → Use LEFT (correct direction)
          widget.controller.rotate90Degrees(RotateDirection.left);
        }
      }
      
      print('   ✅ Controller rotation synchronized to: ${widget.controller.rotation}°');
    } else {
      print('   ✅ Controller rotation already matches target');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Validate rotation state consistency
    if (_rotation != widget.controller.rotation) {
      print('⚠️  Rotation mismatch detected:');
      print('   CropPage state: $_rotation°');
      print('   Controller state: ${widget.controller.rotation}°');
    }
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  child: Builder(
                    builder: (context) {
                      print('🔄 Building CropGridViewer with controller rotation: ${widget.controller.rotation}°');
                      return CropGridViewer.edit(
                        controller: widget.controller,
                        rotateCropArea: true,
                        margin: EdgeInsets.zero,
                      );
                    }
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildRotationControls(),
              const SizedBox(height: 15),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    flex: 2,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Center(
                        child: Text(
                          "Cancel",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: AnimatedBuilder(
                      animation: widget.controller,
                      builder: (_, __) => Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Commented out: Non-functional panorama buttons with duplicate functionality
                              // IconButton(
                              //   onPressed: () =>
                              //       widget.controller.preferredCropAspectRatio =
                              //           widget.controller.preferredCropAspectRatio
                              //               ?.toFraction()
                              //               .inverse()
                              //               .toDouble(),
                              //   icon: widget.controller.preferredCropAspectRatio !=
                              //               null &&
                              //           widget.controller.preferredCropAspectRatio! < 1
                              //       ? const Icon(
                              //           Icons.panorama_vertical_select_rounded)
                              //       : const Icon(
                              //           Icons.panorama_vertical_rounded),
                              // ),
                              // IconButton(
                              //   onPressed: () =>
                              //       widget.controller.preferredCropAspectRatio =
                              //           widget.controller.preferredCropAspectRatio
                              //               ?.toFraction()
                              //               .inverse()
                              //               .toDouble(),
                              //   icon: widget.controller.preferredCropAspectRatio !=
                              //               null &&
                              //           widget.controller.preferredCropAspectRatio! > 1
                              //       ? const Icon(Icons
                              //           .panorama_horizontal_select_rounded)
                              //       : const Icon(
                              //           Icons.panorama_horizontal_rounded),
                              // ),
                            ],
                          ),
                          Row(
                            children: [
                              _buildCropButton(context, null),
                              _buildCropButton(context, 1.toFraction()),
                              _buildCropButton(
                                  context, Fraction.fromString("9/16")),
                              _buildCropButton(
                                  context, Fraction.fromString("3/4")),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: IconButton(
                      onPressed: () {
                        widget.controller.applyCacheCrop();
                        final cropRect = widget.controller.cropRect;
                        print(
                            'CropPage cropRect: left=${cropRect.left}, top=${cropRect.top}, width=${cropRect.width}, height=${cropRect.height}');
                        print('🎯 Applying final changes:');
                        print('   Final rotation: ${widget.controller.rotation}°');
                        print('   CropPage state: $_rotation°');
                        
                        // Rotation already applied in real-time via correct button handlers
                        // No need for complex compensation logic!
                        // Just verify state consistency
                        if (_rotation != widget.controller.rotation) {
                          print('⚠️  State mismatch detected at apply time!');
                          print('   This should not happen with real-time updates!');
                        }
                        
                        Provider.of<VideoEditorProvider>(context, listen: false)
                            .updateCropRect(cropRect);
                        Navigator.pop(context);
                      },
                      icon: Center(
                        child: Text(
                          "Done",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRotationControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const Text(
            'Rotation:',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.rotate_left, color: Colors.white),
            onPressed: _rotateLeft,
            tooltip: 'Rotate Left 90°',
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$_rotation°',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.rotate_right, color: Colors.white),
            onPressed: _rotateRight,
            tooltip: 'Rotate Right 90°',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _resetRotation,
            tooltip: 'Reset Rotation',
          ),
        ],
      ),
    );
  }

  void _rotateLeft() {
    print('🔄 User clicked Rotate Left. Current: $_rotation°');
    print('   Controller before: ${widget.controller.rotation}°');
    setState(() {
      _rotation = (_rotation - 90) % 360;
      if (_rotation < 0) _rotation += 360;
    });
    
    // IMMEDIATE controller update with CORRECT direction
    widget.controller.rotate90Degrees(RotateDirection.left); // LEFT = counter-clockwise
    
    print('   New rotation: $_rotation°, Controller: ${widget.controller.rotation}°');
  }

  void _rotateRight() {
    print('🔄 User clicked Rotate Right. Current: $_rotation°');
    print('   Controller before: ${widget.controller.rotation}°');
    setState(() {
      _rotation = (_rotation + 90) % 360;
    });
    
    // IMMEDIATE controller update with CORRECT direction
    widget.controller.rotate90Degrees(RotateDirection.right); // RIGHT = clockwise
    
    print('   New rotation: $_rotation°, Controller: ${widget.controller.rotation}°');
  }

  void _resetRotation() {
    print('🔄 User clicked Reset Rotation. Current: $_rotation°');
    
    // Calculate how many steps needed to get back to 0°
    final currentControllerRotation = widget.controller.rotation;
    final stepsToReset = currentControllerRotation ~/ 90;
    
    print('   Controller before reset: $currentControllerRotation° ($stepsToReset steps)');
    
    // Reset UI state
    setState(() {
      _rotation = 0;
    });
    
    // Reset controller to match
    for (int i = 0; i < stepsToReset.abs(); i++) {
      if (stepsToReset > 0) {
        widget.controller.rotate90Degrees(RotateDirection.left); // Counter-clockwise to reduce
      } else {
        widget.controller.rotate90Degrees(RotateDirection.right); // Clockwise to increase
      }
    }
    
    print('   Reset complete. CropPage: $_rotation°, Controller: ${widget.controller.rotation}°');
  }

  Widget _buildCropButton(BuildContext context, Fraction? f) {
    if (widget.controller.preferredCropAspectRatio != null &&
        widget.controller.preferredCropAspectRatio! > 1) {
      f = f?.inverse();
    }

    return Flexible(
      child: TextButton(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: widget.controller.preferredCropAspectRatio == f?.toDouble()
              ? Colors.grey.shade800
              : null,
          foregroundColor: widget.controller.preferredCropAspectRatio == f?.toDouble()
              ? Colors.white
              : null,
          textStyle: Theme.of(context).textTheme.bodySmall,
        ),
        onPressed: () => widget.controller.preferredCropAspectRatio = f?.toDouble(),
        child: Text(f == null ? 'free' : '${f.numerator}:${f.denominator}'),
      ),
    );
  }
}
