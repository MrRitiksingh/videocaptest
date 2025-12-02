import 'dart:io';

import 'package:ai_video_creator_editor/components/gradient_scaffold.dart';
import 'package:ai_video_creator_editor/constants/extensions.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../components/file_image_viewer.dart';

class PlayAudioPage extends StatefulWidget {
  final File? file;
  final String? title;
  final String? audioUrl;
  final String? coverUrl;
  final GestureTapCallback? deleteFunction;

  const PlayAudioPage({
    super.key,
    required this.file,
    this.title,
    required this.audioUrl,
    this.coverUrl,
    this.deleteFunction,
  });

  @override
  State<PlayAudioPage> createState() => _PlayAudioPageState();
}

class _PlayAudioPageState extends State<PlayAudioPage> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      // gradientScaffold: true,
      appBar: AppBar(
        title: Text(widget.title ?? ""),
        actions: [
          widget.deleteFunction == null
              ? context.shrink()
              : IconButton(
                  onPressed: widget.deleteFunction,
                  icon: const Icon(Icons.delete_forever),
                ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            widget.coverUrl == null && widget.audioUrl != null
                ? context.shrink()
                : Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10.0),
                      child: CachedNetworkImage(
                        imageUrl: widget.coverUrl ?? "",
                        fit: BoxFit.contain,
                        height: 350,
                      ),
                    ),
                  ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                  child: FileAudioViewer(
                title: "",
                audioFile: widget.file,
                audioUrl: widget.audioUrl,
                onPressed: null,
              )),
            ),
          ],
        ),
      ),
    );
  }
}
