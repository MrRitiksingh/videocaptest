import 'dart:math';

import 'package:ai_video_creator_editor/controllers/video_controller.dart';
import 'package:flutter/material.dart';

Size computeSizeWithRatio(Size layout, double r) {
  if (layout.aspectRatio == r) {
    return layout;
  }

  if (layout.aspectRatio > r) {
    return Size(layout.height * r, layout.height);
  }

  if (layout.aspectRatio < r) {
    return Size(layout.width, layout.width / r);
  }

  assert(false, 'An error occured while computing the aspectRatio');
  return Size.zero;
}

Rect resizeCropToRatio(Size layout, Rect crop, double r) {
  // if target ratio is smaller than current crop ratio
  if (r < crop.size.aspectRatio) {
    // use longest crop side if smaller than layout longest side
    final maxSide = min(crop.longestSide, layout.shortestSide);
    // to calculate the ratio of the new crop area
    final size = Size(maxSide, maxSide / r);

    final rect = Rect.fromCenter(
      center: crop.center,
      width: size.width,
      height: size.height,
    );

    // if res is smaller than layout we can return it
    if (rect.size <= layout) return translateRectIntoBounds(layout, rect);
  }

  // if there is not enough space crop to the middle of the current [crop]
  final newCenteredCrop = computeSizeWithRatio(crop.size, r);
  final rect = Rect.fromCenter(
    center: crop.center,
    width: newCenteredCrop.width,
    height: newCenteredCrop.height,
  );

  // return rect into bounds
  return translateRectIntoBounds(layout, rect);
}

Rect translateRectIntoBounds(Size layout, Rect rect) {
  final double translateX = (rect.left < 0 ? rect.left.abs() : 0) +
      (rect.right > layout.width ? layout.width - rect.right : 0);
  final double translateY = (rect.top < 0 ? rect.top.abs() : 0) +
      (rect.bottom > layout.height ? layout.height - rect.bottom : 0);

  if (translateX != 0 || translateY != 0) {
    return rect.translate(translateX, translateY);
  }

  return rect;
}

double scaleToSize(Size layout, Rect rect) =>
    min(layout.width / rect.width, layout.height / rect.height);

Rect calculateCroppedRect(
  VideoEditorController controller,
  Size layout, {
  Offset? min,
  Offset? max,
}) {
  final Offset minCrop = min ?? controller.minCrop;
  final Offset maxCrop = max ?? controller.maxCrop;

  return Rect.fromPoints(
    Offset(minCrop.dx * layout.width, minCrop.dy * layout.height),
    Offset(maxCrop.dx * layout.width, maxCrop.dy * layout.height),
  );
}

bool isRectContained(Size size, Rect rect) =>
    rect.left >= 0 &&
    rect.top >= 0 &&
    rect.right <= size.width &&
    rect.bottom <= size.height;

double getOppositeRatio(double ratio) => 1 / ratio;

/// Transform text overlay coordinates from original video space to cropped video space
Offset transformTextPositionForCrop(
  Offset originalPosition,
  Rect cropRect,
  Size originalVideoSize,
) {
  // Convert absolute position to relative position in original video
  final relativeX = originalPosition.dx / originalVideoSize.width;
  final relativeY = originalPosition.dy / originalVideoSize.height;

  // Convert crop rect to relative coordinates
  final cropLeft = cropRect.left / originalVideoSize.width;
  final cropTop = cropRect.top / originalVideoSize.height;
  final cropWidth = cropRect.width / originalVideoSize.width;
  final cropHeight = cropRect.height / originalVideoSize.height;

  // Check if text position is within crop area
  if (relativeX < cropLeft ||
      relativeX > (cropLeft + cropWidth) ||
      relativeY < cropTop ||
      relativeY > (cropTop + cropHeight)) {
    // Text is outside crop area, return a position that will be clipped
    return const Offset(-1000, -1000);
  }

  // Transform position to cropped coordinate system
  final newRelativeX = (relativeX - cropLeft) / cropWidth;
  final newRelativeY = (relativeY - cropTop) / cropHeight;

  // Convert back to absolute coordinates in cropped video
  final croppedVideoSize = Size(cropRect.width, cropRect.height);
  return Offset(
    newRelativeX * croppedVideoSize.width,
    newRelativeY * croppedVideoSize.height,
  );
}

/// Transform text overlay coordinates from cropped video space back to original video space
Offset transformTextPositionFromCrop(
  Offset croppedPosition,
  Rect cropRect,
  Size originalVideoSize,
) {
  // Convert cropped position to relative coordinates in cropped space
  final relativeX = croppedPosition.dx / cropRect.width;
  final relativeY = croppedPosition.dy / cropRect.height;

  // Convert crop rect to relative coordinates in original video
  final cropLeft = cropRect.left / originalVideoSize.width;
  final cropTop = cropRect.top / originalVideoSize.height;
  final cropWidth = cropRect.width / originalVideoSize.width;
  final cropHeight = cropRect.height / originalVideoSize.height;

  // Transform to original video coordinate system
  final originalRelativeX = cropLeft + (relativeX * cropWidth);
  final originalRelativeY = cropTop + (relativeY * cropHeight);

  // Convert back to absolute coordinates in original video
  return Offset(
    originalRelativeX * originalVideoSize.width,
    originalRelativeY * originalVideoSize.height,
  );
}

/// Calculate the scale factor for text overlays when crop is applied
double calculateTextScaleForCrop(Rect cropRect, Size originalVideoSize) {
  // Calculate the scale based on the crop area relative to original size
  final cropWidthRatio = cropRect.width / originalVideoSize.width;
  final cropHeightRatio = cropRect.height / originalVideoSize.height;

  // Use the smaller ratio to ensure text fits within the cropped area
  return min(cropWidthRatio, cropHeightRatio);
}
