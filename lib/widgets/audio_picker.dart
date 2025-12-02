import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class AudioPicker extends StatelessWidget {
  const AudioPicker({
    super.key,
    required this.onAudioSelected,
    this.selectedAudioPath,
  });

  final Function(String? audioPath) onAudioSelected;
  final String? selectedAudioPath;

  Future<void> _pickAudio() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null) {
      onAudioSelected(result.files.single.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _pickAudio,
            icon: const Icon(Icons.audio_file),
            label:
                Text(selectedAudioPath != null ? 'Change Audio' : 'Add Audio'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ),
        if (selectedAudioPath != null) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => onAudioSelected(null),
            tooltip: 'Remove Audio',
          ),
        ],
      ],
    );
  }
}
