import 'package:ai_video_creator_editor/screens/project/new_editor/thumbnail_stream_builder.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

enum TrimBoundaries {
  none,
  start,
  end,
  inside,
}

class CustomTrimSlider extends StatefulWidget {
  final double value;
  final double secondValue;
  final double max;
  final double position;
  final Function(double, double) onChanged;
  final Function(double) onPositionChanged; // Add position callback
  final VideoPlayerController? controller;

  const CustomTrimSlider({
    super.key,
    required this.value,
    required this.secondValue,
    required this.max,
    required this.onChanged,
    required this.position,
    required this.onPositionChanged,
    this.controller,
  });

  @override
  State<CustomTrimSlider> createState() => _CustomTrimSliderState();
}

class _CustomTrimSliderState extends State<CustomTrimSlider> {
  late ScrollController _scrollController;
  TrimBoundaries _boundary = TrimBoundaries.none;
  double _minTrimSize = 1.0; // Minimum 1 second

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Rect _getTrimRect() {
    final width = MediaQuery.of(context).size.width;
    return Rect.fromLTRB(
      (widget.value / widget.max) * width,
      0,
      (widget.secondValue / widget.max) * width,
      60,
    );
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_boundary == TrimBoundaries.none) return;
    final width = MediaQuery.of(context).size.width;
    final delta = details.delta.dx / width * widget.max;

    switch (_boundary) {
      case TrimBoundaries.start:
        final newStart = (widget.value + delta)
            .clamp(0.0, widget.secondValue - _minTrimSize);
        widget.onChanged(newStart, widget.secondValue);
        break;
      case TrimBoundaries.end:
        final newEnd = (widget.secondValue + delta)
            .clamp(widget.value + _minTrimSize, widget.max);
        widget.onChanged(widget.value, newEnd);
        break;
      case TrimBoundaries.inside:
        final length = widget.secondValue - widget.value;
        var newStart = (widget.value + delta).clamp(0.0, widget.max - length);
        var newEnd = newStart + length;
        if (newEnd > widget.max) {
          newEnd = widget.max;
          newStart = newEnd - length;
        }
        widget.onChanged(newStart, newEnd);
        break;
      case TrimBoundaries.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final trimRect = _getTrimRect();
    final positionLeft =
        (widget.position / widget.max) * MediaQuery.of(context).size.width;
    final width = MediaQuery.of(context).size.width;

    return Container(
      height: 60,
      width: width,
      color: Colors.black,
      child: Stack(
        clipBehavior: Clip.none, // Allow overflow for handles
        children: [
          SizedBox(
            height: 60,
            child: ThumbnailStreamBuilder(
              controller: widget.controller, // Pass video controller
              scrollController: _scrollController,
            ),
          ),

          // Trim overlay
          Container(
            color: Colors.black54,
          ),

          // Trim selection
          Positioned.fromRect(
            rect: trimRect,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: GestureDetector(
                onHorizontalDragUpdate: (details) {
                  _boundary = TrimBoundaries.inside;
                  _onPanUpdate(details);
                },
              ),
            ),
          ),

          // Start handle
          Positioned(
            left: trimRect.left - 10,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                _boundary = TrimBoundaries.start;
                _onPanUpdate(details);
              },
              child: Container(
                width: 20,
                height: 60,
                color: Colors.white.withOpacity(0.5),
                child: Center(
                  child: Container(
                    width: 4,
                    height: 30,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // cursor
          Positioned(
            left: positionLeft - 1,
            child: Container(
              width: 3,
              height: 60,
              color: Colors.red,
            ),
          ),

          // End handle
          Positioned(
            left: trimRect.right - 10,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                _boundary = TrimBoundaries.end;
                _onPanUpdate(details);
              },
              child: Container(
                width: 20,
                height: 60,
                color: Colors.white.withOpacity(0.5),
                child: Center(
                  child: Container(
                    width: 4,
                    height: 30,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // Time indicators
          Positioned(
            left: trimRect.left,
            bottom: 0,
            child: Text(
              _formatDuration(widget.value),
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          Positioned(
            right: MediaQuery.of(context).size.width - trimRect.right,
            bottom: 0,
            child: Text(
              _formatDuration(widget.secondValue),
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.round());
    return '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}

// class CustomTrimSlider extends StatefulWidget {
//   final double value;
//   final double secondValue;
//   final double position;
//   final double max;
//   final Function(double, double) onChanged;
//   final List<Widget> thumbnails;
//
//   const CustomTrimSlider({
//     super.key,
//     required this.value,
//     required this.secondValue,
//     required this.position,
//     required this.max,
//     required this.onChanged,
//     required this.thumbnails,
//   });
//
//   @override
//   CustomTrimSliderState createState() => CustomTrimSliderState();
// }
//
// class CustomTrimSliderState extends State<CustomTrimSlider> {
//   late ScrollController _scrollController;
//
//   @override
//   void initState() {
//     super.initState();
//     _scrollController = ScrollController();
//   }
//
//   @override
//   void dispose() {
//     _scrollController.dispose();
//     super.dispose();
//   }
//
//   @override
//   void didUpdateWidget(CustomTrimSlider oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     if (widget.position != oldWidget.position) {
//       _scrollToPosition();
//     }
//   }
//
//   void _scrollToPosition() {
//     if (!_scrollController.hasClients) return;
//     final scrollWidth = _scrollController.position.maxScrollExtent;
//     final position = (widget.position / widget.max) * scrollWidth;
//     _scrollController.animateTo(
//       position,
//       duration: Duration(milliseconds: 100),
//       curve: Curves.linear,
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: 60,
//       child: Stack(
//         children: [
//           SingleChildScrollView(
//             controller: _scrollController,
//             scrollDirection: Axis.horizontal,
//             child: Row(children: widget.thumbnails),
//           ),
//           Positioned(
//             left: widget.value / widget.max * MediaQuery.of(context).size.width,
//             child: GestureDetector(
//               onHorizontalDragUpdate: (details) {
//                 final width = MediaQuery.of(context).size.width;
//                 final newValue =
//                     (details.globalPosition.dx / width) * widget.max;
//                 widget.onChanged(
//                   newValue.clamp(0, widget.secondValue),
//                   widget.secondValue,
//                 );
//               },
//               child: Container(
//                 width: 20,
//                 height: 60,
//                 color: Colors.white.withOpacity(0.5),
//               ),
//             ),
//           ),
//           Positioned(
//             left: widget.secondValue /
//                 widget.max *
//                 MediaQuery.of(context).size.width,
//             child: GestureDetector(
//               onHorizontalDragUpdate: (details) {
//                 final width = MediaQuery.of(context).size.width;
//                 final newValue =
//                     (details.globalPosition.dx / width) * widget.max;
//                 widget.onChanged(
//                   widget.value,
//                   newValue.clamp(widget.value, widget.max),
//                 );
//               },
//               child: Container(
//                 width: 20,
//                 height: 60,
//                 color: Colors.white.withOpacity(0.5),
//               ),
//             ),
//           ),
//           // Add playback position indicator
//           Positioned(
//             left: widget.position /
//                 widget.max *
//                 MediaQuery.of(context).size.width,
//             child: Container(
//               width: 2,
//               height: 60,
//               color: Colors.red,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
