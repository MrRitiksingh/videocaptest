import 'package:flutter/material.dart';
import 'package:sliding_up_panel_custom/sliding_up_panel_custom.dart';

import '../constants/colors.dart';

class SlidingUpScaffold extends StatefulWidget {
  final Widget? floatingActionButton;
  final Widget body;
  final Widget panel;
  final PanelController panelController;
  final double? initialMaxHeight;
  final double? initialMinHeight;

  const SlidingUpScaffold({
    super.key,
    this.floatingActionButton,
    required this.body,
    required this.panel,
    required this.panelController,
    this.initialMaxHeight,
    this.initialMinHeight,
  });

  @override
  State<SlidingUpScaffold> createState() => _SlidingUpScaffoldState();
}

class _SlidingUpScaffoldState extends State<SlidingUpScaffold> {
  // final PanelController panelController = PanelController();
  // @override
  // void dispose() {
  //   panelController.dispose();
  //   super.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    return SlidingUpPanel(
      controller: widget.panelController,
      body: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              widget.body,
              SizedBox(height: widget.initialMinHeight ?? 110.0)
            ],
          ),
        ),
      ),
      panel: SizedBox(
        child: Column(
          children: [
            GestureDetector(
              onTap: () {
                if (!widget.panelController.isAttached) return;
                if (widget.panelController.isPanelOpen) {
                  widget.panelController.close();
                } else {
                  widget.panelController.open();
                }
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Container(
                  height: 3.0,
                  width: 60.0,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: kBorderRadius,
                  ),
                ),
              ),
            ),
            widget.panel,
          ],
        ),
      ),
      options: SlidingUpPanelOptions(
        initialMaxHeight: widget.initialMaxHeight ?? 300.0,
        initialMinHeight: widget.initialMinHeight ?? 110.0,
        color: ColorConstants.primaryColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
        parallaxEnabled: true,
        backdropEnabled: true,
      ),
    );
  }
}
