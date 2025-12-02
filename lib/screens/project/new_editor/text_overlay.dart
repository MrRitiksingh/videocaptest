import 'package:ai_video_creator_editor/screens/project/new_editor/text_overlay_manager.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/video_editor_page_updated.dart';
import 'package:flutter/material.dart';

class TextOverlayEditor extends StatefulWidget {
  final Function(TextOverlay) onTextAdded;

  const TextOverlayEditor({super.key, required this.onTextAdded});

  @override
  TextOverlayEditorState createState() => TextOverlayEditorState();
}

class TextOverlayEditorState extends State<TextOverlayEditor> {
  final TextEditingController _controller = TextEditingController();
  Color _selectedColor = Colors.red;
  double _fontSize = 32;

  @override
  Widget build(BuildContext context) {
    return BottomSheetWrapper(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: 'Enter text'),
            ),
            Row(
              children: [
                const Text('Font Size'),
                Expanded(
                  child: Slider(
                    value: _fontSize,
                    min: 12,
                    max: 48,
                    onChanged: (value) => setState(() => _fontSize = value),
                  ),
                ),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: Colors.primaries
                    .map((color) => GestureDetector(
                          onTap: () => setState(() => _selectedColor = color),
                          child: Container(
                            width: 30,
                            height: 30,
                            color: color,
                          ),
                        ))
                    .toList(),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                widget.onTextAdded(TextOverlay(
                  text: _controller.text,
                  position: const Offset(100, 100),
                  color: _selectedColor,
                  style: TextStyle(fontSize: _fontSize),
                ));
                Navigator.pop(context);
              },
              child: const Text('Add Text'),
            ),
          ],
        ),
      ),
    );
  }
}
