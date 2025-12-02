import 'package:flutter/material.dart';
import '../enums/track_type.dart';

class TrackOptions extends StatelessWidget {
  const TrackOptions({
    super.key,
    required this.offset,
    this.trackType = TrackType.video,
    this.onTap,
    this.onTrim,
    this.onPosition,
    this.onDelete,
    this.onMute,
    this.onEditStyle,
    this.onStretch,
    this.isMuted,
    this.showStretch = false,
    this.showMute = true,
  });

  final Offset offset;
  final TrackType trackType;
  final void Function()? onTap;
  final void Function()? onTrim;
  final void Function()? onPosition;
  final void Function()? onDelete;
  final void Function()? onMute;
  final void Function()? onEditStyle;
  final void Function()? onStretch;
  final bool? isMuted;
  final bool showStretch;
  final bool showMute;

  @override
  Widget build(BuildContext context) {
    final bool mutedState = isMuted ?? false;
    // Size of the popup menu - adjust width based on track type and stretch option
    double menuWidth = trackType == TrackType.text ? 280 : 240;
    if (showStretch) menuWidth += 60; // Add space for stretch option
    const double menuHeight = 80;

    // Get screen size
    final screenSize = MediaQuery.of(context).size;

    // Adjusted offset to ensure it stays in screen
    double left = offset.dx;
    double top = offset.dy - menuHeight;

    // Clamp horizontally
    if (left + menuWidth > screenSize.width) {
      left = screenSize.width - menuWidth - 10; // padding from edge
    } else if (left < 10) {
      left = 10;
    }

    // Clamp vertically
    if (top < 10) {
      top = offset.dy + 10; // show below the tap if there's no space above
    }
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 4),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Trim option (available for all track types)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTrim,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cut, color: Colors.white),
                        Text(
                          "Trim",
                          style: TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 20),

                  // Position option (only for audio and text tracks)
                  if (trackType != TrackType.video && onPosition != null) ...[
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onPosition,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.open_with, color: Colors.white),
                          Text(
                            "Position",
                            style: TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 20),
                  ],

                  // Delete option (available for all track types)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onDelete,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete, color: Colors.white),
                        Text(
                          "Delete",
                          style: TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),

                  // Stretch option (only for image-based video tracks)
                  if (showStretch && onStretch != null) ...[
                    SizedBox(width: 20),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onStretch,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.open_in_full, color: Colors.white),
                          Text(
                            "Stretch",
                            style: TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(width: 20),

                  // Show different third option based on track type
                  if (trackType == TrackType.text && onEditStyle != null)
                    // Edit Style option for text tracks
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onEditStyle,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit, color: Colors.white),
                          Text(
                            "Edit",
                            style: TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    )
                  else if (trackType != TrackType.text)
                    // Audio/video track audio controls
                    if (showMute && onMute != null)
                      // Active mute option for videos with audio
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onMute,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              mutedState ? Icons.volume_off : Icons.volume_up,
                              color: mutedState ? Colors.red : Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      )
                    else
                      // Disabled icon for videos without audio
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.volume_off,
                            color: Colors.white.withValues(alpha: 0.3),
                            size: 20,
                          ),
                          Text(
                            "No Audio",
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                        ],
                      ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
