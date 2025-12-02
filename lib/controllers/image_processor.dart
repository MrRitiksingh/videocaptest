import 'dart:io';

import 'package:image/image.dart' as img;

import '../utils/functions.dart';

Future<List<File>> normalizeImages({required List<File> imageFiles}) async {
  if (imageFiles.isEmpty) return [];
  if (imageFiles.length == 1) return imageFiles;

  // First pass: analyze all images to determine target dimensions
  List<ImageDimensions> dimensions = [];
  for (var file in imageFiles) {
    try {
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image != null) {
        dimensions.add(ImageDimensions(
          width: image.width,
          height: image.height,
          aspectRatio: image.width / image.height,
        ));
      }
    } catch (e) {
      safePrint('Error analyzing image: ${file.path}: $e');
    }
  }

  if (dimensions.isEmpty) return imageFiles;

  // Check if all images are already the same size
  bool allSameSize = dimensions.every((d) =>
      d.width == dimensions[0].width && d.height == dimensions[0].height);
  if (allSameSize) return imageFiles;

  // Calculate target dimensions
  final targetDimensions = _calculateTargetDimensions(dimensions);

  // Second pass: resize images
  List<File> processedFiles = [];
  for (var i = 0; i < imageFiles.length; i++) {
    try {
      final bytes = await imageFiles[i].readAsBytes();
      final originalImage = img.decodeImage(bytes);

      if (originalImage == null) {
        processedFiles.add(imageFiles[i]);
        continue;
      }

      final processedImage = await _processImage(
        originalImage,
        targetDimensions.width,
        targetDimensions.height,
      );

      // Save the processed image
      final processedBytes = img.encodeJpg(processedImage);
      final newFile = File('${imageFiles[i].path}_normalized.jpg');
      await newFile.writeAsBytes(processedBytes);
      processedFiles.add(newFile);
    } catch (e) {
      safePrint('Error processing image: ${imageFiles[i].path}: $e');
      processedFiles.add(imageFiles[i]); // Keep original if processing fails
    }
  }

  return processedFiles;
}

Future<img.Image> _processImage(
  img.Image original,
  int targetWidth,
  int targetHeight,
) async {
  // Create a blank canvas with target dimensions
  final canvas = img.Image(
    width: targetWidth,
    height: targetHeight,
    numChannels: 4, // RGBA
  );

  // Fill with transparency
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

  // Calculate resize dimensions maintaining aspect ratio
  double originalAspect = original.width / original.height;
  double targetAspect = targetWidth / targetHeight;

  int newWidth, newHeight;
  if (originalAspect > targetAspect) {
    // Width is the limiting factor
    newWidth = targetWidth;
    newHeight = (targetWidth / originalAspect).round();
  } else {
    // Height is the limiting factor
    newHeight = targetHeight;
    newWidth = (targetHeight * originalAspect).round();
  }

  // Resize the original image
  final resized = img.copyResize(
    original,
    width: newWidth,
    height: newHeight,
    interpolation: img.Interpolation.linear,
  );

  // Calculate position to center the image
  int x = (targetWidth - newWidth) ~/ 2;
  int y = (targetHeight - newHeight) ~/ 2;

  // Compose the resized image onto the canvas
  img.compositeImage(canvas, resized, dstX: x, dstY: y);

  return canvas;
}

class ImageDimensions {
  final int width;
  final int height;
  final double aspectRatio;

  ImageDimensions({
    required this.width,
    required this.height,
    required this.aspectRatio,
  });
}

ImageDimensions _calculateTargetDimensions(List<ImageDimensions> dimensions) {
  // Find the average width and height
  double avgWidth = dimensions.map((d) => d.width).reduce((a, b) => a + b) /
      dimensions.length;
  double avgHeight = dimensions.map((d) => d.height).reduce((a, b) => a + b) /
      dimensions.length;
  int targetWidth = (avgWidth / 2).round() * 2;
  int targetHeight = (avgHeight / 2).round() * 2;
  targetWidth = targetWidth < 100 ? 100 : targetWidth;
  targetHeight = targetHeight < 100 ? 100 : targetHeight;

  return ImageDimensions(
    width: targetWidth,
    height: targetHeight,
    aspectRatio: targetWidth / targetHeight,
  );
}
