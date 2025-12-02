import 'package:flutter/material.dart';

class FloatingAudioMutePanel extends StatelessWidget {
  final bool isOriginalMuted;
  final bool isAddedAudioMuted;
  final bool hasAddedAudio;
  final VoidCallback onToggleOriginalMute;
  final VoidCallback? onToggleAddedAudioMute;

  const FloatingAudioMutePanel({
    Key? key,
    required this.isOriginalMuted,
    required this.isAddedAudioMuted,
    required this.hasAddedAudio,
    required this.onToggleOriginalMute,
    this.onToggleAddedAudioMute,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isOriginalMuted ? Icons.volume_off : Icons.volume_up,
                color: isOriginalMuted ? Colors.red : Colors.white,
                size: 28,
              ),
              tooltip: isOriginalMuted ? 'Unmute Original' : 'Mute Original',
              onPressed: onToggleOriginalMute,
            ),
            if (hasAddedAudio)
              IconButton(
                icon: Icon(
                  isAddedAudioMuted ? Icons.volume_off : Icons.volume_up,
                  color: isAddedAudioMuted ? Colors.red : Colors.white,
                  size: 28,
                ),
                tooltip: isAddedAudioMuted
                    ? 'Unmute Added Audio'
                    : 'Mute Added Audio',
                onPressed: onToggleAddedAudioMute,
              ),
          ],
        ),
      ),
    );
  }
}
