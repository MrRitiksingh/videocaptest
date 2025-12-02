import 'dart:io';
import 'dart:typed_data';

import 'package:ai_video_creator_editor/constants/extensions.dart';
import 'package:ai_video_creator_editor/utils/permissions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

import '../screens/project/projects.dart';

class AssetController extends ChangeNotifier {
  disposeController() {
    allMediaFiles = [];
    selectedMediaFiles = [];
    loading = true;
    thumbnailsTemp = [];
    assetEntityIDS = [];
    requestType = RequestType.common;
  }

  int pageCount = 0;
  int pageSize = 18;
  AssetPathEntity? _path;
  List<AssetEntity> allMediaFiles = [];
  List<AssetEntity> selectedMediaFiles = [];
  bool loading = true;
  bool isLastPage = false;

  updateLoading(bool val) {
    loading = val;
    notifyListeners();
  }

  updateRequestType(RequestType val) {
    requestType = val;
    notifyListeners();
  }


  Future<void> getAssets() async {
    loading = true;
    // notifyListeners();

    // Dynamically request permissions based on requestType
    PermissionState ps;
    if (requestType == RequestType.video) {
      if (Platform.isAndroid) {
        final storagePermission = await Permission.videos.request();
        final mediaPermission = await Permission.photos.request();
        if (!storagePermission.isGranted && !mediaPermission.isGranted) {
          loading = false;
          notifyListeners();
          return;
        }
      }
      ps = await PhotoManager.requestPermissionExtend(
        requestOption: PermissionRequestOption(
          androidPermission: const AndroidPermission(
            type: RequestType.video,
            mediaLocation: false,
          ),
        ),
      );
    } else if (requestType == RequestType.image) {
      ps = await PhotoManager.requestPermissionExtend(
        requestOption: PermissionRequestOption(
          androidPermission: const AndroidPermission(
            type: RequestType.image,
            mediaLocation: false,
          ),
        ),
      );
    } else {
      // Request both for 'All'
      ps = await PhotoManager.requestPermissionExtend(
        requestOption: PermissionRequestOption(
          androidPermission: const AndroidPermission(
            type: RequestType.common,
            mediaLocation: false,
          ),
        ),
      );
    }

    if (!ps.hasAccess) {
      loading = false;
      notifyListeners();
      return;
    }

    // Enhanced filter options for videos
    FilterOptionGroup filter;
    if (requestType == RequestType.video) {
      filter = FilterOptionGroup(
        videoOption: const FilterOption(
          durationConstraint: DurationConstraint(
            min: Duration(milliseconds: 100), // Reduced minimum duration
            max: Duration(hours: 10), // Set reasonable maximum
          ),
          sizeConstraint: SizeConstraint(
            minWidth: 1,
            minHeight: 1,
            ignoreSize: false,
          ),
        ),
        orders: [
          const OrderOption(
            type: OrderOptionType.createDate,
            asc: false,
          ),
        ],
      );
    } else if (requestType == RequestType.image) {
      filter = FilterOptionGroup(
        imageOption: const FilterOption(
          sizeConstraint: SizeConstraint(ignoreSize: true),
        ),
      );
    } else {
      filter = FilterOptionGroup(
        imageOption: const FilterOption(
          sizeConstraint: SizeConstraint(ignoreSize: true),
        ),
        videoOption: const FilterOption(
          durationConstraint: DurationConstraint(
            min: Duration(milliseconds: 100),
          ),
          sizeConstraint: SizeConstraint(
            minWidth: 1,
            minHeight: 1,
            ignoreSize: false,
          ),
        ),
      );
    }

    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      onlyAll: true,
      filterOption: filter,
      type: requestType,
    );

    if (paths.isEmpty) {
      loading = false;
      notifyListeners();
      return;
    }

    _path = paths.first;
    pageCount = 0;
    isLastPage = false;

    // Get assets with error handling
    try {
      allMediaFiles = await _path!.getAssetListPaged(
        page: pageCount,
        size: pageSize,
      );

      if (allMediaFiles.length < pageSize) {
        isLastPage = true;
      }

      // Debug print to check if videos are being fetched
      if (requestType == RequestType.video) {
        print('Fetched ${allMediaFiles.length} videos');
        for (var asset in allMediaFiles.take(5)) {
          print(
              'Video: ${asset.title}, Duration: ${asset.duration}, Size: ${asset.size}');
        }
      }
    } catch (e) {
      print('Error fetching assets: $e');
      allMediaFiles = [];
    }

    loading = false;
    notifyListeners();
  }


  Future<void> loadMoreAssets() async {
    if (isLastPage) return;
    await Future.delayed(Duration(milliseconds: 300));
    pageCount++;
    final files = await _path!.getAssetListPaged(
      page: pageCount,
      size: pageSize,
    );

    if (files.length < pageSize) {
      isLastPage = true;
    }

    allMediaFiles.addAll(files);
    notifyListeners();
  }

  getAllMedia(BuildContext context) async {
    PermissionStatus permissionStatus = await getGalleryPermission();
    if (permissionStatus.isGranted) {
      permissionStatus = await Permission.photos.request();
    }
    await showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return Container(
            margin: EdgeInsets.only(top: kToolbarHeight),
            height: MediaQuery.of(context).size.height - (kToolbarHeight * 0),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(10.0)),
            ),
            child: Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: false,
                title: const Text("Media"),
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(10.0)),
                ),
                actions: [
                  IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close)),
                ],
              ),
              floatingActionButton: selectedMediaFiles.isEmpty
                  ? null
                  : FloatingActionButton(
                      onPressed: loading
                          ? () {}
                          : () => processSelectedMedia(
                              context: context, navigate: false),
                      backgroundColor: Colors.blueAccent,
                      shape: const CircleBorder(),
                      child: loading
                          ? const Center(
                              child: CupertinoActivityIndicator(),
                            )
                          : const Icon(
                              Icons.check,
                              color: Colors.white,
                            ),
                    ),
              bottomNavigationBar: selectedMediaFiles.isEmpty
                  ? context.shrink()
                  : SizedBox(
                      height: 80.0,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Row(
                              children: selectedMediaFiles.map(
                                (element) {
                                  return Container(
                                    height: 75,
                                    width: 75.0,
                                    margin: const EdgeInsets.all(4.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(2.0),
                                      child: GalleryThumbnail(
                                        asset: element,
                                        thumbFuture:
                                            thumbnailUint8List(element),
                                      ),
                                    ),
                                  );
                                },
                              ).toList(),
                            ),
                            const SizedBox(height: 10, width: 200),
                          ],
                        ),
                      ),
                    ),
              body: ListView(
                children: [
                  GridView.extent(
                    shrinkWrap: true,
                    maxCrossAxisExtent: 150,
                    childAspectRatio: 0.75,
                    physics: const ScrollPhysics(),
                    children: allMediaFiles.map(
                      (element) {
                        bool selected = selectedMediaFiles.contains(element);
                        return GestureDetector(
                          onTap: () {
                            if (loading) return;
                            if (selected) {
                              selectedMediaFiles.remove(element);
                            } else {
                              selectedMediaFiles.add(element);
                            }
                            setState(() {});
                          },
                          child: Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.all(4.0),
                                decoration: !selected
                                    ? const BoxDecoration()
                                    : BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(4.0),
                                        border: Border.all(
                                          width: 4.0,
                                          color: Colors.blueAccent,
                                        ),
                                      ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  alignment: Alignment.center,
                                  children: [
                                    Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(1.0),
                                          child: GalleryThumbnail(
                                            asset: element,
                                            thumbFuture:
                                                thumbnailUint8List(element),
                                          ),
                                        ),
                                        element.type == AssetType.video
                                            ? GestureDetector(
                                                onTap: () {},
                                                child: const Icon(
                                                  Icons.play_arrow_sharp,
                                                  size: 80.0,
                                                ),
                                              )
                                            : context.shrink(),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Center(
                                child: !selected
                                    ? context.shrink()
                                    : const CircleAvatar(
                                        radius: 24.0,
                                        child: Center(
                                          child: Icon(
                                            Icons.check_circle,
                                            size: 40.0,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        );
                      },
                    ).toList(),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
    return;
  }

  RequestType requestType = RequestType.common;

  /// Thumbnails

  List<Uint8List> thumbnailsTemp = [];
  List<String> assetEntityIDS = [];

  Future<Uint8List?> thumbnailUint8List(AssetEntity assetEntity) async {
    if (assetEntityIDS.contains(assetEntity.id)) {
      int index = assetEntityIDS.indexOf(assetEntity.id);
      return thumbnailsTemp[index];
    }
    Uint8List? result = await assetEntity.thumbnailDataWithSize(
      const ThumbnailSize(500, 500),
      quality: 10,
      format: ThumbnailFormat.jpeg,
    );
    if (result != null) {
      thumbnailsTemp.add(result);
      assetEntityIDS.add(assetEntity.id);
    }
    return result;
  }

  /// Music
  final OnAudioQuery _audioQuery = OnAudioQuery();
  List<SongModel> allSongs = [];

  Future<List<SongModel>> fetchAllSongs() async {
    try {
      allSongs = await _audioQuery.querySongs(
        sortType: SongSortType.DISPLAY_NAME,
        orderType: OrderType.ASC_OR_SMALLER,
      );
      // notifyListeners();
      return allSongs;
    } catch (err) {
      // notifyListeners();
      return [];
    }
  }

  disposeAllSongs() {
    allSongs = [];
  }
}
