import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:flick_video_player/flick_video_player.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class FileImageViewer extends StatelessWidget {
  final String? title;
  final File? imageFile;
  final String? imageUrl;
  final VoidCallback onPressed;
  final FileDataSourceType? fileDataSourceType;

  const FileImageViewer({
    super.key,
    this.title,
    /*required*/ this.imageFile,
    this.imageUrl,
    required this.onPressed,
    /*required*/ this.fileDataSourceType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: Flex(
        direction: Axis.vertical,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title != null
              ? Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(title!, style: const TextStyle(fontSize: 20)),
                )
              : const SizedBox.shrink(),
          Center(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: fileDataSourceType == null ||
                          fileDataSourceType == FileDataSourceType.file
                      ? Image.file(
                          imageFile!,
                          fit: BoxFit.contain,
                        )
                      : CachedNetworkImage(
                          imageUrl: imageUrl!,
                          fit: BoxFit.cover,
                          width: MediaQuery.of(context).size.width,
                          progressIndicatorBuilder: (ctx, t, m) =>
                              const Center(child: CupertinoActivityIndicator()),
                        ),
                ),
                Positioned(
                  top: 10.0,
                  right: 10.0,
                  child: IconButton(
                    onPressed: onPressed,
                    icon: const Icon(
                      Icons.delete_forever,
                      color: Colors.grey,
                    ),
                  ),
                )
                // IconButton(
                //   onPressed: onPressed,
                //   icon: const Icon(
                //     Icons.delete_forever_rounded,
                //   ),
                // )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FileMultiImageViewer extends StatelessWidget {
  final String? title;
  final File? imageFile;
  final String? imageUrl;
  final VoidCallback onPressed;
  final FileDataSourceType? fileDataSourceType;

  const FileMultiImageViewer({
    super.key,
    this.title,
    /*required*/ this.imageFile,
    this.imageUrl,
    required this.onPressed,
    /*required*/ this.fileDataSourceType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title != null
              ? Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(title!, style: const TextStyle(fontSize: 20)),
                )
              : const SizedBox.shrink(),
          Center(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: fileDataSourceType == null ||
                          fileDataSourceType == FileDataSourceType.file
                      ? Image.file(
                          imageFile!,
                          fit: BoxFit.contain,
                        )
                      : CachedNetworkImage(
                          imageUrl: imageUrl!,
                          fit: BoxFit.cover,
                          width: MediaQuery.of(context).size.width,
                        ),
                ),
                Positioned(
                  top: 10.0,
                  right: 10.0,
                  child: IconButton(
                    onPressed: onPressed,
                    icon: const Icon(
                      Icons.delete_forever,
                      color: Colors.grey,
                    ),
                  ),
                )
                // IconButton(
                //   onPressed: onPressed,
                //   icon: const Icon(
                //     Icons.delete_forever_rounded,
                //   ),
                // )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum FileDataSourceType { network, file, memory }

class FileVideoViewer extends StatefulWidget {
  final String? title;
  final String? videoFilePath;
  final VoidCallback onPressed;
  final FileDataSourceType fileDataSourceType;
  final bool? hideDeleteIcon;
  final String? thumbnailImagerUrl;

  const FileVideoViewer({
    super.key,
    this.title,
    /*required*/ this.videoFilePath,
    required this.onPressed,
    required this.fileDataSourceType,
    this.hideDeleteIcon = false,
    this.thumbnailImagerUrl,
  });

  @override
  State<FileVideoViewer> createState() => _FileVideoViewerState();
}

class _FileVideoViewerState extends State<FileVideoViewer> {
  FlickManager? flickManager;

  /// cached
  late CachedVideoPlayerPlusController controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  double? _actualAspectRatio;

  /// cached
  bool videoFromUrl = false;

  /// Get the best available aspect ratio
  double get effectiveAspectRatio {
    if (_actualAspectRatio != null && _actualAspectRatio! > 0) {
      return _actualAspectRatio!;
    }

    if (videoFromUrl && controller.value.aspectRatio > 0) {
      return controller.value.aspectRatio;
    }

    if (flickManager
                ?.flickVideoManager?.videoPlayerController?.value.aspectRatio !=
            null &&
        flickManager!
                .flickVideoManager!.videoPlayerController!.value.aspectRatio >
            0) {
      return flickManager!
          .flickVideoManager!.videoPlayerController!.value.aspectRatio;
    }

    // Fallback to 16:9 for landscape videos, 9:16 for portrait
    return 16 / 9;
  }

  initVideo() async {
    videoFromUrl = widget.fileDataSourceType == FileDataSourceType.network &&
        widget.videoFilePath != null;
    setState(() {});
    if (videoFromUrl) {
      controller = CachedVideoPlayerPlusController.networkUrl(
        Uri.parse(
          widget.videoFilePath!,
        ),
        httpHeaders: {
          'Connection': 'keep-alive',
        },
        invalidateCacheIfOlderThan: const Duration(days: 7),
      )..initialize().then((value) async {
          try {
            await controller.setLooping(false);
            _isInitialized = true;
            _isPlaying = false;
            _actualAspectRatio = controller.value.aspectRatio;
            print('Video initialized - Aspect Ratio: $_actualAspectRatio');
            // controller.play();

            // Add listener to show play button when video ends
            controller.addListener(() {
              if (mounted && controller.value.isInitialized) {
                final isControllerPlaying = controller.value.isPlaying;
                final position = controller.value.position;
                final duration = controller.value.duration;

                // Sync our state with controller's playing state
                // Show play button when: controller stopped AND video is near/at end
                if (!isControllerPlaying &&
                    _isPlaying &&
                    position.inMilliseconds >= (duration.inMilliseconds - 100)) {
                  setState(() {
                    _isPlaying = false;
                  });
                }
              }
            });

            if (mounted) setState(() {});
          } catch (e) {
            debugPrint('Video controller initialization error: $e');
            if (mounted) {
              setState(() {
                _isInitialized = false;
                _isPlaying = false;
              });
            }
          }
        }).catchError((error) {
          debugPrint('Video controller initialization failed: $error');
          if (mounted) {
            setState(() {
              _isInitialized = false;
              _isPlaying = false;
            });
          }
        });
    } else if (widget.fileDataSourceType == FileDataSourceType.network) {
      final videoController = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoFilePath ?? ""));
      videoController.initialize().then((_) {
        if (mounted) {
          setState(() {
            _actualAspectRatio = videoController.value.aspectRatio;
            print(
                'Network video initialized - Aspect Ratio: $_actualAspectRatio');
          });
        }
      });
      setState(() {
        flickManager = createEnhancedFlickManager(videoController);
      });
    } else if (widget.fileDataSourceType == FileDataSourceType.file) {
      final videoController =
          VideoPlayerController.file(File(widget.videoFilePath ?? ""));
      videoController.initialize().then((_) {
        if (mounted) {
          setState(() {
            _actualAspectRatio = videoController.value.aspectRatio;
            print('File video initialized - Aspect Ratio: $_actualAspectRatio');
          });
        }
      });
      setState(() {
        flickManager = createEnhancedFlickManager(videoController);
      });
    } else if (widget.fileDataSourceType == FileDataSourceType.memory) {
      /// to_do for web branch
      // videoPlayerController =
      //     VideoPlayerController.file(File(widget.videoFilePath))
      //       ..initialize().then((_) {
      //         setState(() {
      //           chewieController = ChewieController(
      //             videoPlayerController: videoPlayerController!,
      //             autoPlay: false,
      //             looping: false,
      //             aspectRatio: videoPlayerController?.value.aspectRatio,
      //           );
      //         });
      //       });
      setState(() {});
    }
    setState(() {});
  }

  /// Create enhanced FlickManager with larger controls for full-screen
  FlickManager createEnhancedFlickManager(VideoPlayerController controller) {
    return FlickManager(
      videoPlayerController: controller,
      autoPlay: false,
      // Enhanced auto-hide duration for better usability
      autoInitialize: true,
    );
  }

  /// Custom control theme for enhanced button sizes
  Widget buildEnhancedFlickVideoPlayer() {
    return Theme(
      data: Theme.of(context).copyWith(
        // Enhanced icon theme for larger buttons
        iconTheme: const IconThemeData(
          size: 48.0, // Larger icon size for better visibility
          color: Colors.white,
        ),
        // Enhanced button theme for larger touch targets
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: const Size(64, 64), // Larger minimum button size
            padding: const EdgeInsets.all(16),
            iconSize: 48.0, // Larger icon size for full-screen
          ),
        ),
      ),
      child: FlickVideoPlayer(
        flickManager: flickManager!,
      ),
    );
  }

  @override
  void initState() {
    initVideo();
    super.initState();
  }

  @override
  void dispose() {
    flickManager?.dispose();
    if (videoFromUrl && _isInitialized) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          // horizontal: MediaQuery.of(context).size.width >= 1000
          //     ? MediaQuery.of(context).size.width / 4
          //     : 4.0,
          vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.title != null
              ? Padding(
                  padding: const EdgeInsets.all(4.0),
                  child:
                      Text(widget.title!, style: const TextStyle(fontSize: 20)),
                )
              : const SizedBox.shrink(),
          Center(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Builder(builder: (context) {
                    if (videoFromUrl) {
                      if (controller.value.isInitialized) {
                        return GestureDetector(
                          onTap: () {
                            if (_isInitialized) {
                              setState(() {
                                _isPlaying = !_isPlaying;
                                _isPlaying
                                    ? controller.play()
                                    : controller.pause();
                              });
                            }
                          },
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final screenWidth =
                                  MediaQuery.of(context).size.width;
                              final maxHeight =
                                  MediaQuery.of(context).size.height * 0.6;

                              double videoWidth =
                                  screenWidth - 12; // Account for padding
                              double videoHeight =
                                  videoWidth / effectiveAspectRatio;

                              if (videoHeight > maxHeight) {
                                videoHeight = maxHeight;
                                videoWidth = maxHeight * effectiveAspectRatio;
                              }

                              return Center(
                                child: SizedBox(
                                  width: videoWidth,
                                  height: videoHeight,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    fit: StackFit.loose,
                                    children: [
                                      AspectRatio(
                                        aspectRatio: effectiveAspectRatio,
                                        child:
                                            CachedVideoPlayerPlus(controller),
                                      ),
                                      if (_isInitialized && !_isPlaying)
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.black
                                                .withValues(alpha: 0.5),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.play_arrow,
                                            color: Colors.white,
                                            size: 30,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      } else if (widget.thumbnailImagerUrl != null) {
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final screenWidth =
                                MediaQuery.of(context).size.width;
                            final maxHeight =
                                MediaQuery.of(context).size.height * 0.6;

                            double videoWidth =
                                screenWidth - 12; // Account for padding
                            double videoHeight =
                                videoWidth / effectiveAspectRatio;

                            if (videoHeight > maxHeight) {
                              videoHeight = maxHeight;
                              videoWidth = maxHeight * effectiveAspectRatio;
                            }

                            return Center(
                              child: SizedBox(
                                width: videoWidth,
                                height: videoHeight,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CachedNetworkImage(
                                      imageUrl: widget.thumbnailImagerUrl ?? "",
                                      fit: BoxFit.cover,
                                      width: videoWidth,
                                      height: videoHeight,
                                      progressIndicatorBuilder: (a, b, c) =>
                                          const Center(
                                        child: CupertinoActivityIndicator(),
                                      ),
                                    ),
                                    const Center(
                                        child: CupertinoActivityIndicator()),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }
                      return const Center(child: CupertinoActivityIndicator());
                    }
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final screenWidth = MediaQuery.of(context).size.width;
                        final maxHeight =
                            MediaQuery.of(context).size.height * 0.6;

                        double videoWidth =
                            screenWidth - 12; // Account for padding
                        double videoHeight = videoWidth / effectiveAspectRatio;

                        if (videoHeight > maxHeight) {
                          videoHeight = maxHeight;
                          videoWidth = maxHeight * effectiveAspectRatio;
                        }

                        return Center(
                          child: SizedBox(
                            width: videoWidth,
                            height: videoHeight,
                            child: ClipRect(
                              child: AspectRatio(
                                aspectRatio: effectiveAspectRatio,
                                child: buildEnhancedFlickVideoPlayer(),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ),
                widget.hideDeleteIcon == true
                    ? const SizedBox.shrink()
                    : Positioned(
                        top: 10.0,
                        right: 10.0,
                        child: GestureDetector(
                          onTap: widget.onPressed,
                          child: const Icon(
                            Icons.delete_forever,
                            color: Colors.grey,
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FileImageViewerNetwork extends StatelessWidget {
  final String? title;
  final String imageUrl;
  final VoidCallback onPressed;

  const FileImageViewerNetwork({
    super.key,
    this.title,
    required this.imageUrl,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title != null
              ? Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(title!, style: const TextStyle(fontSize: 20)),
                )
              : const SizedBox.shrink(),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                top: 10.0,
                right: 10.0,
                child: IconButton(
                  onPressed: onPressed,
                  icon: const Icon(
                    Icons.delete_forever,
                    color: Colors.grey,
                  ),
                ),
              )
              // IconButton(
              //   onPressed: onPressed,
              //   icon: const Icon(
              //     Icons.delete_forever_rounded,
              //   ),
              // )
            ],
          ),
        ],
      ),
    );
  }
}

class FileAudioViewer extends StatefulWidget {
  final String? title;
  final File? audioFile;
  final String? audioUrl;
  final VoidCallback? onPressed;

  const FileAudioViewer({
    super.key,
    this.title,
    this.audioFile,
    this.onPressed,
    this.audioUrl,
  });

  @override
  State<FileAudioViewer> createState() => _FileAudioViewerState();
}

class _FileAudioViewerState extends State<FileAudioViewer> {
  final AudioPlayer player = AudioPlayer();

  // Create a player
  bool isPlaying = false;

  playerPlay() {
    // player.i
    player.setSource(widget.audioFile == null && widget.audioUrl != null
        ? UrlSource(widget.audioUrl!)
        : DeviceFileSource(widget.audioFile!.path));
    player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          isPlaying = state == PlayerState.playing;
        });
      }
    });

    player.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          duration = newDuration;
        });
      }
    });
    player.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          position = newPosition;
        });
      }
    });
  }

  Duration? duration = const Duration();
  Duration position = const Duration();

  String formatTime(int seconds) {
    return "${Duration(seconds: seconds)}".split(".")[0].padLeft(8, "0");
  }

  @override
  void initState() {
    playerPlay();
    super.initState();
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.title != null
              ? Padding(
                  padding: const EdgeInsets.all(4.0),
                  child:
                      Text(widget.title!, style: const TextStyle(fontSize: 20)),
                )
              : const SizedBox.shrink(),
          // StreamBuilder<PlayerState>(
          //   stream: player.onPlayerStateChanged,
          //   builder: (context, snapshot) {
          //     final playerStateEnum = snapshot.data!;
          //     final processingState = playerState.stopped;
          //     final playing = playerState.playing;
          //     // final processingState = playerState == PlayerState.stopped;
          //     // final playing = playerState == PlayerState.playing;
          //     if (processingState) {
          //       return Container(
          //         margin: const EdgeInsets.all(8.0),
          //         child: const CupertinoActivityIndicator(),
          //       );
          //     } else if (playing != true) {
          //       return Center(
          //         child: IconButton(
          //           icon: const Icon(Icons.play_arrow),
          //           onPressed: () async => await player.resume(),
          //         ),
          //       );
          //     } else if (processingState == false) {
          //       return Center(
          //         child: IconButton(
          //           icon: const Icon(Icons.pause),
          //           onPressed: player.pause,
          //         ),
          //       );
          //     } else {
          //       return Center(
          //         child: IconButton(
          //           icon: const Icon(Icons.replay),
          //           // iconSize: 64.0,
          //           onPressed: () => player.seek(Duration.zero),
          //         ),
          //       );
          //     }
          //   },
          // ),
          /* widget.audioUrl != null && player.getDuration() == Duration.zero
              ? const Center(child: CircularProgressIndicator())
              :*/
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  if (isPlaying) {
                    player.pause();
                  } else {
                    player.play(
                        widget.audioFile == null && widget.audioUrl != null
                            ? UrlSource(widget.audioUrl!)
                            : DeviceFileSource(widget.audioFile!.path));
                  }
                },
                icon: Icon(!isPlaying ? Icons.play_arrow_sharp : Icons.pause,
                    size: 30.0),
              ),
              const SizedBox(width: 20.0),
              IconButton(
                onPressed: () =>
                    [player.stop(), setState(() => position = Duration.zero)],
                icon: const Icon(Icons.stop, size: 30.0),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              // mainAxisSize: MainAxisSize.min,
              children: [
                Text(formatTime(position.inSeconds)),
                Text(formatTime((duration! - position).inSeconds))
              ],
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Slider(
                  value: position.inSeconds.toDouble(),
                  onChanged: (value) {
                    position = Duration(seconds: value.toInt());
                    player.seek(position);
                    player.resume();
                  },
                  min: 0,
                  max: duration!.inSeconds.toDouble(),
                ),
                widget.onPressed == null
                    ? const SizedBox.shrink()
                    : Align(
                        alignment: Alignment.bottomRight,
                        child: IconButton(
                          onPressed: widget.onPressed,
                          icon: const Icon(
                            Icons.delete_forever,
                            color: Colors.grey,
                          ),
                        ),
                      )
                // IconButton(
                //   onPressed: onPressed,
                //   icon: const Icon(
                //     Icons.delete_forever_rounded,
                //   ),
                // )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
