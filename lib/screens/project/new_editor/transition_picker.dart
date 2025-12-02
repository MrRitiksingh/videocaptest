// transition_picker.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class TransitionPicker extends StatefulWidget {
  final int trackIndex; // Index of track BEFORE the transition
  final Function(TransitionType) onTransitionSelected;
  final TransitionType currentTransition;

  const TransitionPicker({
    super.key,
    required this.trackIndex,
    required this.onTransitionSelected,
    required this.currentTransition,
  });

  @override
  State<TransitionPicker> createState() => _TransitionPickerState();
}

class _TransitionPickerState extends State<TransitionPicker> {
  late TransitionType selectedTransitionType;
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  @override
  void initState() {
    super.initState();
    selectedTransitionType = widget.currentTransition;

    // Auto-scroll to selected transition after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedTransition();
    });
  }

  @override
  void dispose() {
    // ItemScrollController doesn't require disposal
    super.dispose();
  }

  /// Auto-scroll to currently selected transition (now super simple with scrollable_positioned_list!)
  void _scrollToSelectedTransition() {
    if (!mounted) return;

    final selectedIndex = TransitionType.values.indexOf(selectedTransitionType);
    if (selectedIndex < 0) return;

    // Jump to index with center alignment
    // alignment: 0.5 aligns the item's leading edge to viewport center
    _itemScrollController.jumpTo(
      index: selectedIndex,
      alignment: 0.5,
    );

    print(
        '📜 Auto-scrolled to transition: ${selectedTransitionType.name} (index: $selectedIndex) using scrollable_positioned_list');
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(10.0),
            child: Text(
              "Transition: Video ${widget.trackIndex + 1} → Video ${widget.trackIndex + 2}",
              style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            height: 200,
            child: Column(
              children: [
                if (selectedTransitionType == TransitionType.none)
                  SizedBox(
                    height: 150,
                    width: 150,
                  )
                else
                  Image.asset(
                    'assets/gifs/${selectedTransitionType.toString().split('.').last}.gif',
                    height: 150,
                    width: 150,
                  ),
                SizedBox(height: 5),
                Expanded(
                  child: ScrollablePositionedList.separated(
                    itemScrollController: _itemScrollController,
                    itemPositionsListener: _itemPositionsListener,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    itemCount: TransitionType.values.length,
                    separatorBuilder: (context, index) => SizedBox(width: 40),
                    itemBuilder: (context, index) {
                      final transition = TransitionType.values[index];
                      final color =
                          transition.name == selectedTransitionType.name
                              ? Colors.deepPurple
                              : null;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            setState(() => selectedTransitionType = transition),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.animation,
                                  color: color,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  transition.toString().split('.').last,
                                  style: TextStyle(
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom:
                    MediaQuery.of(context).viewPadding.bottom > 0 ? 16.0 : 24.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Cancel"),
                  ),
                  // Show Delete button only if transition is not "none"
                  if (selectedTransitionType != TransitionType.none)
                    IconButton(
                      onPressed: () {
                        // Set transition to none and close
                        widget.onTransitionSelected(TransitionType.none);
                        Navigator.pop(context);
                      },
                      icon: Icon(Icons.delete),
                      color: Colors.red,
                      tooltip: 'Remove Transition',
                      iconSize: 28,
                    ),
                  ElevatedButton(
                    onPressed: () {
                      widget.onTransitionSelected(selectedTransitionType);
                      Navigator.pop(context);
                    },
                    child: Text("Select"),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum TransitionType {
  none,
  fade,
  fadeblack,
  fadewhite,
  distance,
  wipeleft,
  wiperight,
  wipeup,
  wipedown,
  slideleft,
  slideright,
  slideup,
  slidedown,
  smoothleft,
  smoothright,
  smoothup,
  smoothdown,
  circlecrop,
  rectcrop,
  circleclose,
  circleopen,
  horzclose,
  horzopen,
  vertclose,
  vertopen,
  diagbl,
  diagbr,
  diagtl,
  diagtr,
  fadegrays,
  squeezev,
  squeezeh,
  zoomin,
}

class TransitionPreview extends StatelessWidget {
  final TransitionType type;
  final VideoPlayerController controller;

  const TransitionPreview({
    Key? key,
    required this.type,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Implementation of transition preview effects
    switch (type) {
      case TransitionType.fade:
        return FadeTransition(
          opacity: controller.value.isPlaying
              ? const AlwaysStoppedAnimation(0.5)
              : const AlwaysStoppedAnimation(1.0),
          child: VideoPlayer(controller),
        );
      // Add other transition effects
      default:
        return Container();
    }
  }
}

class LimitedTransitionPicker extends StatefulWidget {
  final int trackIndex;
  final List<TransitionType> allowedTransitions;
  final Function(TransitionType) onTransitionSelected;
  final TransitionType currentTransition;

  const LimitedTransitionPicker({
    super.key,
    required this.trackIndex,
    required this.allowedTransitions,
    required this.onTransitionSelected,
    required this.currentTransition,
  });

  @override
  State<LimitedTransitionPicker> createState() =>
      _LimitedTransitionPickerState();
}

class _LimitedTransitionPickerState extends State<LimitedTransitionPicker> {
  late TransitionType selectedTransition;
  final ItemScrollController _scrollController = ItemScrollController();
  final ItemPositionsListener _positionsListener =
      ItemPositionsListener.create();

  @override
  void initState() {
    super.initState();
    selectedTransition = widget.currentTransition;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoScrollToSelected();
    });
  }

  /// Scroll to selected transition
  void _autoScrollToSelected() {
    final index = widget.allowedTransitions.indexOf(selectedTransition);
    if (index < 0) return;

    _scrollController.jumpTo(index: index, alignment: 0.5);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Text(
              "Transition (Start/End)",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),

          // Preview GIF
          SizedBox(
            height: 200,
            child: Column(
              children: [
                if (selectedTransition == TransitionType.none)
                  SizedBox(height: 150, width: 150)
                else
                  Image.asset(
                    'assets/gifs/${selectedTransition.name}.gif',
                    height: 150,
                    width: 150,
                  ),

                const SizedBox(height: 5),

                // Horizontal List
                Expanded(
                  child: ScrollablePositionedList.separated(
                    scrollDirection: Axis.horizontal,
                    itemScrollController: _scrollController,
                    itemPositionsListener: _positionsListener,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: widget.allowedTransitions.length,
                    separatorBuilder: (_, __) => SizedBox(width: 40),
                    itemBuilder: (context, index) {
                      final transition = widget.allowedTransitions[index];
                      final isActive = transition == selectedTransition;

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            setState(() => selectedTransition = transition),
                        child: Row(
                          children: [
                            Icon(
                              Icons.animation,
                              color: isActive ? Colors.deepPurple : Colors.white,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              transition.name,
                              style: TextStyle(
                                color: isActive
                                    ? Colors.deepPurple
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Buttons
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom:
                    MediaQuery.of(context).viewPadding.bottom > 0 ? 16 : 24,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Cancel
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Cancel"),
                  ),

                  // Delete only when not NONE
                  if (selectedTransition != TransitionType.none)
                    IconButton(
                      iconSize: 28,
                      tooltip: "Remove Transition",
                      color: Colors.red,
                      icon: Icon(Icons.delete),
                      onPressed: () {
                        widget.onTransitionSelected(TransitionType.none);
                        Navigator.pop(context);
                      },
                    ),

                  // Select
                  ElevatedButton(
                    onPressed: () {
                      widget.onTransitionSelected(selectedTransition);
                      Navigator.pop(context);
                    },
                    child: Text("Select"),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
