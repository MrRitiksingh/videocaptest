// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:ai_video_creator_editor/screens/project/models/overlay_video_track_model.dart';
// import 'package:provider/provider.dart';
// import 'package:ai_video_creator_editor/screens/project/new_editor/video_editor_provider.dart';
// import 'package:ai_video_creator_editor/components/track_options.dart';
// import 'package:ai_video_creator_editor/widgets/overlay_video_trimmer.dart';

// enum TrimBoundaries { none, start, end, inside }

// class OverlayVideoTrack extends StatefulWidget {
//   const OverlayVideoTrack({
//     super.key,
//     required this.overlayVideoTrack,
//     required this.index,
//     required this.isSelected,
//     required this.timelineWidth,
//     required this.timelineDuration,
//     required this.selectedTrackBorderColor,
//   });

//   final OverlayVideoTrackModel overlayVideoTrack;
//   final int index;
//   final bool isSelected;
//   final double timelineWidth;
//   final double timelineDuration;
//   final Color selectedTrackBorderColor;

//   @override
//   State<OverlayVideoTrack> createState() => _OverlayVideoTrackState();
// }

// class _OverlayVideoTrackState extends State<OverlayVideoTrack>
//     with AutomaticKeepAliveClientMixin {
//   TrimBoundaries _boundary = TrimBoundaries.none;
//   Rect _trimRect = Rect.zero;
//   double _trimStart = 0.0;
//   double _trimEnd = 0.0;
//   OverlayEntry? _overlayEntry;
//   final GlobalKey _trackKey = GlobalKey();

//   @override
//   void initState() {
//     super.initState();
//     _trimStart = widget.overlayVideoTrack.trimStartTime;
//     _trimEnd = widget.overlayVideoTrack.trimEndTime;
//   }

//   Rect _getTrimRect() {
//     double left = (_trimStart / widget.timelineDuration) * widget.timelineWidth;
//     double right = (_trimEnd / widget.timelineDuration) * widget.timelineWidth;
//     left = left.isNaN ? 0 : left;
//     right = right.isNaN ? 0 : right;
//     return Rect.fromLTRB(left, 0, right, 30);
//   }

//   void _onPanUpdate(DragUpdateDetails details) {
//     if (_boundary == TrimBoundaries.none || !widget.isSelected) return;
//     final overlayTracks =
//         context.read<VideoEditorProvider>().overlayVideoTracks;
//     final isFirstTrack = widget.index == 0;
//     final isLastTrack = widget.index == overlayTracks.length - 1;
//     final double lowerLimit = (overlayTracks.length == 1 || isFirstTrack)
//         ? 0
//         : overlayTracks[widget.index - 1].trimEndTime;
//     final double upperLimit = (overlayTracks.length == 1 || isLastTrack)
//         ? widget.timelineDuration.toDouble()
//         : overlayTracks[widget.index + 1].trimStartTime;
//     final delta =
//         details.delta.dx / widget.timelineWidth * widget.timelineDuration;
//     const double minTrimSize = 1;
//     void updateTrim(double newStart, double newEnd) {
//       _trimStart = newStart;
//       _trimEnd = newEnd;
//       context
//           .read<VideoEditorProvider>()
//           .updateOverlayVideoTrack(widget.index, _trimStart, _trimEnd);
//     }

//     switch (_boundary) {
//       case TrimBoundaries.start:
//         updateTrim(
//             (_trimStart + delta).clamp(lowerLimit, _trimEnd - minTrimSize),
//             _trimEnd);
//         break;
//       case TrimBoundaries.end:
//         updateTrim(_trimStart,
//             (_trimEnd + delta).clamp(_trimStart + minTrimSize, upperLimit));
//         break;
//       case TrimBoundaries.inside:
//         final length = _trimEnd - _trimStart;
//         var newStart =
//             (_trimStart + delta).clamp(lowerLimit, upperLimit - length);
//         updateTrim(newStart, newStart + length);
//         break;
//       case TrimBoundaries.none:
//         break;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     super.build(context);
//     _trimRect = _getTrimRect();
//     final fileName = widget.overlayVideoTrack.videoFile.path.split('/').last;
//     final provider = context.watch<VideoEditorProvider>();
//     final isMuted = provider.isVideoMuted(widget.overlayVideoTrack.id);
//     return SizedBox(
//       width: widget.timelineWidth,
//       child: Stack(
//         clipBehavior: Clip.none,
//         children: [
//           Positioned.fromRect(
//             rect: _trimRect,
//             child: Container(
//               decoration: BoxDecoration(
//                 border: Border.all(
//                   color: widget.selectedTrackBorderColor,
//                   width: 2,
//                 ),
//               ),
//               child: Row(
//                 children: [
//                   GestureDetector(
//                     behavior: HitTestBehavior.opaque,
//                     key: _trackKey,
//                     onTap: () {},
//                     onLongPress: () => _showOverlay(context),
//                     onHorizontalDragUpdate: (details) {
//                       _boundary = TrimBoundaries.inside;
//                       _onPanUpdate(details);
//                     },
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 12),
//                       alignment: Alignment.centerLeft,
//                       child: Text(
//                         "${(_trimEnd - _trimStart).toStringAsFixed(1)} | $fileName",
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           // Start handle
//           if (widget.isSelected)
//             Positioned(
//               left: _trimRect.left - 10,
//               child: GestureDetector(
//                 behavior: HitTestBehavior.opaque,
//                 onHorizontalDragUpdate: (details) {
//                   _boundary = TrimBoundaries.start;
//                   _onPanUpdate(details);
//                 },
//                 child: Container(
//                   width: 20,
//                   height: 30,
//                   decoration: BoxDecoration(
//                     color: widget.selectedTrackBorderColor,
//                     borderRadius: const BorderRadius.only(
//                       topLeft: Radius.circular(4),
//                       bottomLeft: Radius.circular(4),
//                     ),
//                   ),
//                   child: Center(
//                     child: Container(
//                       width: 2,
//                       height: 15,
//                       decoration: BoxDecoration(
//                         color: Colors.grey,
//                         borderRadius: BorderRadius.all(
//                           Radius.circular(double.maxFinite),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           // End handle
//           if (widget.isSelected)
//             Positioned(
//               left: _trimRect.right - 10,
//               child: GestureDetector(
//                 behavior: HitTestBehavior.opaque,
//                 onHorizontalDragUpdate: (details) {
//                   _boundary = TrimBoundaries.end;
//                   _onPanUpdate(details);
//                 },
//                 child: Container(
//                   width: 20,
//                   height: 30,
//                   decoration: BoxDecoration(
//                     color: widget.selectedTrackBorderColor,
//                     borderRadius: const BorderRadius.only(
//                       topRight: Radius.circular(4),
//                       bottomRight: Radius.circular(4),
//                     ),
//                   ),
//                   child: Center(
//                     child: Container(
//                       width: 2,
//                       height: 15,
//                       decoration: BoxDecoration(
//                         color: Colors.grey,
//                         borderRadius: BorderRadius.all(
//                           Radius.circular(double.maxFinite),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   void _showOverlay(BuildContext context) {
//     final RenderBox renderBox =
//         _trackKey.currentContext?.findRenderObject() as RenderBox;
//     final Offset offset = renderBox.localToGlobal(Offset.zero);
//     final provider = context.read<VideoEditorProvider>();
//     final isMuted = provider.isVideoMuted(widget.overlayVideoTrack.id);
//     _overlayEntry = OverlayEntry(
//       builder: (context) => TrackOptions(
//         offset: offset,
//         onTap: _hideOverlay,
//         onTrim: () async {
//           _hideOverlay();
//           // Open the trimmer for this overlay
//           final result = await Navigator.push<Map<String, dynamic>>(
//             context,
//             MaterialPageRoute(
//               builder: (context) => OverlayVideoTrimmer(
//                 videoFile: widget.overlayVideoTrack.videoFile,
//                 videoDuration: widget.overlayVideoTrack.totalDuration,
//                 remainVideoDuration: provider.videoDuration -
//                     widget.overlayVideoTrack.trimStartTime,
//               ),
//             ),
//           );
//           if (result != null) {
//             provider.updateOverlayVideoTrack(
//               widget.index,
//               widget.overlayVideoTrack.trimStartTime,
//               widget.overlayVideoTrack.trimStartTime +
//                   (result['totalDuration'] as double),
//               opacity: result['opacity'] as double?,
//               blendMode: result['blendMode'] as String?,
//               position: result['position'] as Rect?,
//             );
//           }
//         },
//         onDelete: () {
//           provider.removeOverlayVideoTrack(widget.index);
//           _hideOverlay();
//         },
//         onMute: () {
//           provider.toggleVideoMute(widget.overlayVideoTrack.id);
//           _hideOverlay();
//         },
//         isMuted: isMuted,
//       ),
//     );
//     Overlay.of(context).insert(_overlayEntry!);
//   }

//   void _hideOverlay() {
//     _overlayEntry?.remove();
//     _overlayEntry = null;
//   }

//   @override
//   bool get wantKeepAlive => true;
// }
