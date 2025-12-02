import 'package:ai_video_creator_editor/components/gradient_scaffold.dart';
import 'package:ai_video_creator_editor/routes/route_names.dart';
import 'package:ai_video_creator_editor/screens/project/projects.dart';
import 'package:ai_video_creator_editor/screens/tools/play.dart';
import 'package:ai_video_creator_editor/utils/permissions.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import '../components/clippers.dart';
import 'home/home.dart';

class Landing extends StatefulWidget {
  const Landing({super.key});

  @override
  State<Landing> createState() => _LandingState();
}

class _LandingState extends State<Landing> {
  @override
  void initState() {
    getGalleryPermission();
    super.initState();
  }

  PageController? pageController = PageController();
  int page = 0;
  bool projects = false;
  @override
  Widget build(BuildContext context) {
    return CupertinoScaffold(
      transitionBackgroundColor: Colors.transparent,
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          GradientScaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(
                page == 0
                    ? "Home"
                    : page == 1
                        ? "Play"
                        : "",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SizedBox(
                    height: 40,
                    width: 40,
                    child: GestureDetector(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6.0),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color.fromRGBO(21, 14, 53, 0.3),
                              Color.fromRGBO(21, 13, 50, 0.3),
                              Color.fromRGBO(18, 10, 46, 0.3),
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.menu,
                          size: 30,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                )
              ],
            ),
            body: projects
                ? const Projects()
                : Stack(
                    children: [
                      PageView(
                        controller: pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: const [
                          Home(),
                          PlayTab(),
                        ],
                      ),
                    ],
                  ),
          ),
          SizedBox(
            width: MediaQuery.of(context).size.width,
            child: ClipPath(
              clipper: InwardCurveClipper(),
              child: Container(
                height: kBottomNavigationBarHeight + 20,
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                decoration: const BoxDecoration(
                  // color: Colors.transparent,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.fromRGBO(21, 14, 53, 1),
                      Color.fromRGBO(21, 13, 50, 1),
                      Color.fromRGBO(18, 10, 46, 1),
                    ],
                  ),
                ),
                child: ClipPath(
                  clipper: InwardCurveClipper(),
                  child: Flex(
                    direction: Axis.horizontal,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.min,
                    children: homeIcons.map((ico) {
                      int index = homeIcons.indexOf(ico);
                      return GestureDetector(
                        onTap: () => setState(
                          () => [
                            page = index,
                            pageController?.jumpToPage(page),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            ico.icon,
                            size: 40.0,
                            color: page == index ? Colors.white : Colors.grey,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: CustomPaint(
              painter: MyPainter(),
              child: SizedBox(
                height: 100,
                width: 180,
                child: Container(
                  height: 50,
                  width: 50,
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(25.0),
                  constraints:
                      const BoxConstraints.tightFor(width: 50, height: 50),
                  child: GestureDetector(
                    onTap: () =>
                        Navigator.pushNamed(context, RouteNames.projects),
                    child: Container(
                      height: 50,
                      width: 50,
                      constraints:
                          const BoxConstraints.tightFor(width: 50, height: 50),
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(color: Colors.white, blurRadius: 10.0)
                          ]),
                      child: const Center(
                        child: Icon(
                          Icons.add,
                          color: Color.fromRGBO(11, 43, 118, 1),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Icon> homeIcons = [
    const Icon(Icons.home),
    const Icon(Icons.play_circle),
  ];
}
