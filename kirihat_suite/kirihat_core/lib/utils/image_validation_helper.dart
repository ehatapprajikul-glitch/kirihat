import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class ImageValidationHelper {
  // Product Image Rules
  static const int maxProductWidth = 1200;
  static const int maxProductHeight = 1200;
  static const int maxFileSizeMB = 2;
  static const int maxFileSizeBytes = maxFileSizeMB * 1024 * 1024;

  // Icon/Category Image Rules
  static const int maxIconWidth = 512;
  static const int maxIconHeight = 512;
  static const int maxIconSizeMB = 1;
  static const int maxIconSizeBytes = maxIconSizeMB * 1024 * 1024;

  /// Validates and compresses product image
  /// Returns a Map with 'success', 'message', 'error', and 'bytes' (if successful)
  static Future<Map<String, dynamic>> validateProductImage(XFile file) async {
    try {
      // Check file size
      int fileSize = await file.length();
      if (fileSize > maxFileSizeBytes) {
        return {
          'success': false,
          'error': 'Image too large (max ${maxFileSizeMB}MB). Current: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)}MB',
        };
      }

      // Read and decode image
      Uint8List bytes = await file.readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image == null) {
        return {'success': false, 'error': 'Invalid image file'};
      }

      // Check dimensions
      if (image.width > maxProductWidth || image.height > maxProductHeight) {
        // Resize image if too large
        img.Image resized = img.copyResize(
          image,
          width: image.width > maxProductWidth ? maxProductWidth : null,
          height: image.height > maxProductHeight ? maxProductHeight : null,
        );

        // Compress to bytes
        Uint8List compressed = Uint8List.fromList(img.encodeJpg(resized, quality: 85));

        return {
          'success': true,
          'message': 'Image resized to ${resized.width}x${resized.height}',
          'compressed': true,
          'bytes': compressed, // Return processed bytes
        };
      }

      // Compress even if dimensions are okay (optimization)
      Uint8List compressed = Uint8List.fromList(img.encodeJpg(image, quality: 85));
      
      // Use compressed if smaller, otherwise original
      if (compressed.length < bytes.length) {
        return {
          'success': true,
          'message': 'Image compressed successfully',
          'compressed': true,
          'bytes': compressed,
        };
      }

      return {
        'success': true,
        'message': 'Image validated successfully',
        'compressed': false,
        'bytes': bytes, // Return original bytes if no compression needed
      };
    } catch (e) {
      return {'success': false, 'error': 'Error processing image: $e'};
    }
  }

  /// Validates and compresses icon/category image
  static Future<Map<String, dynamic>> validateIconImage(XFile file) async {
    try {
      // Check file size
      int fileSize = await file.length();
      if (fileSize > maxIconSizeBytes) {
        return {
          'success': false,
          'error': 'Icon too large (max ${maxIconSizeMB}MB). Current: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)}MB',
        };
      }

      // Read and decode image
      Uint8List bytes = await file.readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image == null) {
        return {'success': false, 'error': 'Invalid image file'};
      }

      // Check dimensions and resize if needed
      if (image.width > maxIconWidth || image.height > maxIconHeight) {
        img.Image resized = img.copyResize(
          image,
          width: maxIconWidth,
          height: maxIconHeight,
        );

        Uint8List compressed = Uint8List.fromList(img.encodeJpg(resized, quality: 90));

        return {
          'success': true,
          'message': 'Icon resized to ${maxIconWidth}x${maxIconHeight}',
          'compressed': true,
          'bytes': compressed,
        };
      }

      // Compress
      Uint8List compressed = Uint8List.fromList(img.encodeJpg(image, quality: 90));
      
      return {
        'success': true,
        'message': 'Icon validated successfully',
        'compressed': true,
        'bytes': compressed.length < bytes.length ? compressed : bytes,
      };
    } catch (e) {
      return {'success': false, 'error': 'Error processing icon: $e'};
    }
  }
}
