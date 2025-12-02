import 'package:ai_video_creator_editor/components/gradient_scaffold.dart';
import 'package:flutter/cupertino.dart';

class SimpleVideoEditorPage extends StatefulWidget {
  const SimpleVideoEditorPage({super.key});

  @override
  State<SimpleVideoEditorPage> createState() => _SimpleVideoEditorPageState();
}

class _SimpleVideoEditorPageState extends State<SimpleVideoEditorPage> {
  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: ListView(
        children: [],
      ),
    );
  }
}
