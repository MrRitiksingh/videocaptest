import 'package:ai_video_creator_editor/screens/project/new_editor/video_editor_page_updated.dart';
import 'package:flutter/material.dart';

class CaptionEditor extends StatefulWidget {
  final Function(VideoCaption) onCaptionAdded;

  const CaptionEditor({super.key, required this.onCaptionAdded});

  @override
  State<CaptionEditor> createState() => _CaptionEditorState();
}

class _CaptionEditorState extends State<CaptionEditor> {
  final TextEditingController _textController = TextEditingController();
  double _startTime = 0.0;
  double _endTime = 0.0;

  @override
  Widget build(BuildContext context) {
    return BottomSheetWrapper(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Caption Text',
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration:
                        const InputDecoration(labelText: 'Start Time (s)'),
                    keyboardType: TextInputType.number,
                    onChanged: (value) =>
                        _startTime = double.tryParse(value) ?? 0.0,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration:
                        const InputDecoration(labelText: 'End Time (s)'),
                    keyboardType: TextInputType.number,
                    onChanged: (value) =>
                        _endTime = double.tryParse(value) ?? 0.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                widget.onCaptionAdded(VideoCaption(
                  text: _textController.text,
                  startTime: _startTime,
                  endTime: _endTime,
                ));
                Navigator.pop(context);
              },
              child: const Text('Add Caption'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}

class VideoCaption {
  final String text;
  final double startTime;
  final double endTime;

  VideoCaption({
    required this.text,
    required this.startTime,
    required this.endTime,
  });
}
