import 'package:ai_video_creator_editor/constants/extensions.dart';
import 'package:ai_video_creator_editor/generated/assets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CustomStyleCard extends StatelessWidget {
  final GestureTapCallback onTap;
  final bool selected;
  final String imageUrl;
  final String title;

  const CustomStyleCard({
    super.key,
    required this.onTap,
    required this.selected,
    required this.imageUrl,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    bool portraitOrientation =
        MediaQuery.of(context).orientation == Orientation.portrait ||
            (MediaQuery.of(context).size.width < 1668 &&
                MediaQuery.of(context).orientation == Orientation.portrait);
    double height = portraitOrientation
        ? MediaQuery.of(context).size.height / 6 // For smaller screens
        : MediaQuery.of(context).size.height / 3;
    return Padding(
      padding: const EdgeInsets.all(3.0),
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          // width: MediaQuery.of(context).size.width / 3.5,
          width: 105.0,
          height: 130.0,
          // height: height,
          // decoration: BoxDecoration(
          //   image: imageUrl == null
          //       ? null
          //       : DecorationImage(image: CachedNetworkImageProvider(imageUrl)),
          // ),
          // width: MediaQuery.of(context).size.width / 3.5,
          // height: MediaQuery.of(context).size.height / 6,
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(
                  color: selected == true ? Colors.blue : Colors.grey,
                  width: selected == true ? 2 : 0.75,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: Column(
                  // direction: Axis.vertical,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      // flex: 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7.0),
                        child: imageUrl.isEmpty
                            ? Image.asset(
                                Assets.imagesLogo,
                                width: MediaQuery.of(context).size.width,
                                fit: BoxFit.cover,
                              )
                            : CachedNetworkImage(
                                imageUrl: imageUrl,
                                width: double.maxFinite,
                                height: double.maxFinite,
                                fit: BoxFit.cover,
                                progressIndicatorBuilder: (BuildContext context,
                                    String url, DownloadProgress progress) {
                                  return const Center(
                                    child: CupertinoActivityIndicator(),
                                  );
                                },
                                errorWidget: (ctx, url, error) => Image.asset(
                                  Assets.imagesLogo,
                                  fit: BoxFit.cover,
                                ),
                                errorListener: (obj) {},
                              ),
                      ),
                    ),
                    const SizedBox(height: 5.0),
                    FittedBox(
                      // flex: 1,
                      child: Text(
                        "$title",
                        // 'very long text with a lot of words',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CustomStyleCardName extends StatelessWidget {
  final GestureTapCallback onTap;
  final bool selected;
  final String imageUrl;
  final String? title;

  const CustomStyleCardName({
    super.key,
    required this.onTap,
    required this.selected,
    required this.imageUrl,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    bool portraitOrientation =
        MediaQuery.of(context).orientation == Orientation.portrait ||
            (MediaQuery.of(context).size.width < 1668 &&
                MediaQuery.of(context).orientation == Orientation.portrait);
    double height = portraitOrientation
        ? MediaQuery.of(context).size.height / 6 // For smaller screens
        : MediaQuery.of(context).size.height / 3;
    return Padding(
      padding: const EdgeInsets.all(3.0),
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          // width: MediaQuery.of(context).size.width / 3.5,
          width: 105.0,
          height: 130.0,
          // height: height,
          // decoration: BoxDecoration(
          //   image: imageUrl == null
          //       ? null
          //       : DecorationImage(image: CachedNetworkImageProvider(imageUrl)),
          // ),
          // width: MediaQuery.of(context).size.width / 3.5,
          // height: MediaQuery.of(context).size.height / 6,
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(
                  color: selected == true ? Colors.blue : Colors.grey,
                  width: selected == true ? 2 : 0.75,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: Column(
                  // direction: Axis.vertical,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      // flex: 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7.0),
                        child: imageUrl.isEmpty
                            ? Image.asset(
                                "assets/card/signin.jpg",
                                width: MediaQuery.of(context).size.width,
                                fit: BoxFit.cover,
                              )
                            : CachedNetworkImage(
                                imageUrl: imageUrl,
                                width: double.maxFinite,
                                height: double.maxFinite,
                                fit: BoxFit.cover,
                                progressIndicatorBuilder: (BuildContext context,
                                    String url, DownloadProgress progress) {
                                  return const Center(
                                    child: CupertinoActivityIndicator(),
                                  );
                                },
                                errorWidget: (ctx, url, error) => Image.asset(
                                  "assets/images/logo.png",
                                  fit: BoxFit.cover,
                                ),
                                errorListener: (obj) {},
                              ),
                      ),
                    ),
                    ((title == null) || (title?.isEmpty == true))
                        ? context.shrink()
                        : const SizedBox(height: 5.0),
                    ((title == null) || (title?.isEmpty == true))
                        ? context.shrink()
                        : FittedBox(
                            // flex: 1,
                            child: Text(
                              "$title",
                              // 'very long text with a lot of words',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
