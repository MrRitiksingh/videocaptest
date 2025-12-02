import 'package:ai_video_creator_editor/routes/route_names.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  ScrollController scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.zero,
      children: [
        ListTile(
          title: Text("Video GPT"),
          subtitle: Text("Lorem ipsum"),
          trailing: CupertinoListTileChevron(),
          onTap: () => Navigator.pushNamed(context, RouteNames.videoGpt),
        ),
      ],
    );
  }
}
