import 'dart:ui';

import 'package:flutter/material.dart';

const double sigma = 80.0;

class GradientScaffold extends StatelessWidget {
  final AppBar? appBar;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? floatingActionButton;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Drawer? drawer;
  final bool? extendBodyBehindAppBar;
  final bool? resizeToAvoidBottomInset;
  final Color? backgroundColor;

  const GradientScaffold({
    super.key,
    this.appBar,
    this.floatingActionButtonLocation,
    this.floatingActionButton,
    required this.body,
    this.bottomNavigationBar,
    this.drawer,
    this.extendBodyBehindAppBar = false,
    this.resizeToAvoidBottomInset,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.loose,
      children: [
        Container(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromRGBO(15, 56, 126, 1),
                Color.fromRGBO(15, 56, 126, 1),
              ],
            ),
          ),
          child: Stack(
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height,
                width: MediaQuery.of(context).size.width,
                child: const SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      SizedBox(height: 200),
                      TwoCirclesWidget(),
                      TwoCirclesWidget(),
                      TwoCirclesWidget(),
                      TwoCirclesWidget(),
                      TwoCirclesWidget(),
                    ],
                  ),
                ),
              ),
              ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: Scaffold(
                    appBar: appBar == null
                        ? null
                        : AppBar(
                            title: appBar?.title,
                            leading: appBar?.leading,
                            actions: appBar?.actions,
                            centerTitle: appBar?.centerTitle,
                            backgroundColor:
                                backgroundColor ?? Colors.transparent,
                          ),
                    floatingActionButtonLocation: floatingActionButtonLocation,
                    floatingActionButton: floatingActionButton,
                    body: body,
                    backgroundColor: backgroundColor ?? Colors.transparent,
                    bottomNavigationBar: bottomNavigationBar,
                    drawer: drawer,
                    extendBodyBehindAppBar: extendBodyBehindAppBar ?? false,
                    resizeToAvoidBottomInset: resizeToAvoidBottomInset,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TwoCirclesWidget extends StatelessWidget {
  const TwoCirclesWidget({super.key});

  // final Color firstColor = const Color.fromRGBO(42, 74, 107, 1);
  final Color firstColor = Colors.tealAccent;

  // final Color secondColor = const Color.fromRGBO(74, 18, 80, 1);
  final Color secondColor = const Color(0xffFF53C0);
  final double blurRadius = 300.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background Container
        Container(
          width: double.infinity,
          height: 600,
          color: Colors.transparent, // Background color
        ),
        // Top left circle
        Positioned(
          top: 100,
          left: -50,
          child: Container(
            // height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: firstColor.withOpacity(0.1),
              boxShadow: [
                BoxShadow(
                  color: firstColor,
                  blurRadius: blurRadius,
                ),
                BoxShadow(
                  color: firstColor,
                  blurRadius: blurRadius,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 100, // Adjust the radius for circle size
              backgroundColor: firstColor.withOpacity(0.1),
            ),
          ),
        ),
        // Bottom right circle
        Positioned(
          bottom: 100,
          right: -50,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: secondColor.withOpacity(0.1),
              boxShadow: [
                BoxShadow(
                  color: secondColor,
                  blurRadius: blurRadius,
                ),
                BoxShadow(
                  color: secondColor,
                  blurRadius: blurRadius,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 100, // Adjust the radius for circle size
              backgroundColor: secondColor.withOpacity(0.1),
            ),
          ),
        ),
      ],
    );
  }
}
