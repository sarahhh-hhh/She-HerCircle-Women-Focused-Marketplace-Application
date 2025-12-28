import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class ImageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  /// Pick image from gallery
  Future<XFile?> pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      return image;
    } catch (e) {
      throw 'Failed to pick image: $e';
    }
  }

  /// Pick image from camera
  Future<XFile?> pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
      );
      return image;
    } catch (e) {
      throw 'Failed to pick image: $e';
    }
  }

  /// Resize image to 400x400 and convert to data URL (base64)
  /// Returns the data URL string
  Future<String> resizeImageToDataUrl({
    required XFile imageFile,
  }) async {
    try {
      print('=== Starting image processing ===');
      print('Image path: ${imageFile.path}');

      // Read the image file
      print('Reading image bytes...');
      final imageBytes = await imageFile.readAsBytes();
      print('Image size: ${imageBytes.length} bytes');

      // Decode the image
      print('Decoding image...');
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception(
            'Failed to decode image - image is null. File might be corrupted.');
      }

      print('Original image size: ${image.width}x${image.height}');

      // Resize to 400x400 while maintaining aspect ratio
      print('Resizing to 400x400...');
      final resizedImage = img.copyResize(
        image,
        width: 400,
        height: 400,
        interpolation: img.Interpolation.linear,
      );

      // Encode as PNG
      print('Encoding to PNG...');
      final resizedImageBytes = Uint8List.fromList(img.encodePng(resizedImage));
      print('Resized image size: ${resizedImageBytes.length} bytes');

      // Convert to base64 data URL
      print('Converting to data URL...');
      final base64String = base64Encode(resizedImageBytes);
      final dataUrl = 'data:image/png;base64,$base64String';
      print('Data URL created, length: ${dataUrl.length}');

      return dataUrl;
    } catch (e) {
      print('ERROR in resizeImageToDataUrl: $e');
      rethrow;
    }
  }

  /// Delete image from Firebase Storage by URL (kept for backward compatibility)
  Future<void> deleteImage(String imageUrl) async {
    try {
      // If it's a data URL, no need to delete from storage
      if (imageUrl.startsWith('data:')) {
        print('Skipping deletion for data URL');
        return;
      }

      final Reference imageRef = _storage.refFromURL(imageUrl);
      await imageRef.delete();
    } catch (e) {
      throw 'Failed to delete image: $e';
    }
  }

  /// Display image widget that handles both data URLs and network URLs
  static Widget displayImage(
    String? imageUrl, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    BorderRadius? borderRadius,
    bool isCircle = false,
  }) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Icon(Icons.image_not_supported, color: Colors.grey[400]);
    }

    // Check if it's a data URL
    if (imageUrl.startsWith('data:image')) {
      try {
        // Extract base64 string from data URL
        final base64Index = imageUrl.indexOf(',');
        if (base64Index == -1) {
          return Icon(Icons.image_not_supported, color: Colors.grey[400]);
        }

        final base64String = imageUrl.substring(base64Index + 1);
        final imageBytes = base64Decode(base64String);

        Widget imageWidget = Image.memory(
          imageBytes,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return Icon(Icons.image_not_supported, color: Colors.grey[400]);
          },
        );

        // Apply border radius if specified
        if (borderRadius != null && !isCircle) {
          imageWidget = ClipRRect(
            borderRadius: borderRadius,
            child: imageWidget,
          );
        } else if (isCircle) {
          imageWidget = ClipOval(child: imageWidget);
        }

        return imageWidget;
      } catch (e) {
        print('Error decoding data URL: $e');
        return Icon(Icons.image_not_supported, color: Colors.grey[400]);
      }
    }

    // Handle regular network URLs
    Widget imageWidget = Image.network(
      imageUrl,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Icon(Icons.image_not_supported, color: Colors.grey[400]);
      },
    );

    // Apply border radius if specified
    if (borderRadius != null && !isCircle) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius,
        child: imageWidget,
      );
    } else if (isCircle) {
      imageWidget = ClipOval(child: imageWidget);
    }

    return imageWidget;
  }
}
