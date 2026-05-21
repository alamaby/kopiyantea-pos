import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../utils/result.dart';

enum ImageSource_ { gallery, camera }

/// FEAT-012b — crop aspect ratio preset. Use [square] for product photos
/// so MenuGrid thumbnails align; [free] for logo/QRIS where the source
/// aspect is meaningful.
enum CropAspect {
  /// No crop step — pick → compress → upload.
  none,

  /// Force 1:1.
  square,

  /// Allow any aspect — user drags freely.
  free,
}

enum ImageUploadError {
  cancelled,
  permissionDenied,
  pickFailed,
  cropCancelled,
  compressFailed,
  uploadFailed,
  notAuthenticated,
}

/// Shared image upload pipeline:
///   1. Pick from gallery / camera via `image_picker`
///   2. Resize to max 1024px + JPEG q=80 via `flutter_image_compress`
///   3. Upload to Supabase Storage public bucket
///   4. Return the public URL
///
/// Used by:
/// - FEAT-012 product photos (bucket: `product-images`)
/// - FEAT-013 static QRIS (bucket: `qris-images`)
///
/// Buckets must be created in Supabase with **public read** + RLS write
/// policy gating to authenticated `owner` role. See migration
/// `20260520150001_storage_buckets.sql`.
class ImageUploadService {
  ImageUploadService();

  final Logger _log = Logger();
  final ImagePicker _picker = ImagePicker();

  SupabaseClient? get _sb {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Picks + (optionally crops) + compresses + uploads. Returns the
  /// public URL on success.
  ///
  /// [bucket] = Supabase Storage bucket name.
  /// [pathPrefix] = folder within the bucket, e.g. `products/` — the file
  /// will be saved as `{pathPrefix}{uuidv7}.jpg`.
  /// [crop] = if not [CropAspect.none], inserts a crop step between pick
  /// and compress. User can pinch/drag to frame the subject. Cancelling
  /// the crop returns [ImageUploadError.cropCancelled].
  Future<Result<String, ImageUploadError>> pickAndUpload({
    required ImageSource_ source,
    required String bucket,
    required String pathPrefix,
    CropAspect crop = CropAspect.none,
  }) async {
    final sb = _sb;
    if (sb == null) return const Err(ImageUploadError.notAuthenticated);

    final XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source == ImageSource_.gallery
            ? ImageSource.gallery
            : ImageSource.camera,
        // Initial coarse downscale — flutter_image_compress does the
        // fine-grained pass afterwards.
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
    } catch (e) {
      _log.w('[Image] pick failed', error: e);
      return const Err(ImageUploadError.pickFailed);
    }
    if (picked == null) return const Err(ImageUploadError.cancelled);

    // Crop (optional).
    String pathForCompress = picked.path;
    if (crop != CropAspect.none) {
      try {
        final cropped = await ImageCropper().cropImage(
          sourcePath: picked.path,
          aspectRatio: crop == CropAspect.square
              ? const CropAspectRatio(ratioX: 1, ratioY: 1)
              : null, // null = free aspect
          compressFormat: ImageCompressFormat.jpg,
          compressQuality: 95, // we re-compress below; keep crop output high
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Atur Foto',
              toolbarColor: const Color(0xFF0F766E), // brand teal
              toolbarWidgetColor: const Color(0xFFFFFFFF),
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: crop == CropAspect.square,
              hideBottomControls: crop == CropAspect.square,
            ),
            IOSUiSettings(
              title: 'Atur Foto',
              aspectRatioLockEnabled: crop == CropAspect.square,
              resetAspectRatioEnabled: crop == CropAspect.free,
            ),
          ],
        );
        if (cropped == null) {
          return const Err(ImageUploadError.cropCancelled);
        }
        pathForCompress = cropped.path;
      } catch (e) {
        _log.w('[Image] crop failed', error: e);
        return const Err(ImageUploadError.pickFailed);
      }
    }

    // Compress.
    Uint8List? compressed;
    try {
      compressed = await FlutterImageCompress.compressWithFile(
        pathForCompress,
        minWidth: 1024,
        minHeight: 1024,
        quality: 80,
        format: CompressFormat.jpeg,
      );
    } catch (e) {
      _log.w('[Image] compress failed', error: e);
      return const Err(ImageUploadError.compressFailed);
    }
    if (compressed == null) {
      return const Err(ImageUploadError.compressFailed);
    }

    // Upload.
    final filename = '$pathPrefix${const Uuid().v7()}.jpg';
    try {
      await sb.storage.from(bucket).uploadBinary(
            filename,
            compressed,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
      final url = sb.storage.from(bucket).getPublicUrl(filename);
      _log.i('[Image] uploaded $bucket/$filename');
      return Ok(url);
    } catch (e, st) {
      _log.e('[Image] upload failed', error: e, stackTrace: st);
      return const Err(ImageUploadError.uploadFailed);
    }
  }

  /// Removes an uploaded image. Best-effort — failures are logged but
  /// don't block the caller. Use when replacing a photo so we don't
  /// accumulate orphaned objects.
  Future<void> deleteByUrl(String url, {required String bucket}) async {
    final sb = _sb;
    if (sb == null) return;
    try {
      // Public URL format: .../object/public/<bucket>/<path>
      final marker = '/object/public/$bucket/';
      final idx = url.indexOf(marker);
      if (idx < 0) {
        _log.w('[Image] cannot parse storage path from URL: $url');
        return;
      }
      final path = url.substring(idx + marker.length);
      await sb.storage.from(bucket).remove([path]);
      _log.i('[Image] deleted $bucket/$path');
    } catch (e) {
      _log.w('[Image] delete failed (orphan left in storage)', error: e);
    }
  }

  /// Optional helper: returns true when Supabase is initialized so the UI
  /// can hide upload buttons in pure-offline mode.
  bool get isAvailable => _sb != null;
}

final imageUploadServiceProvider = Provider<ImageUploadService>(
  (_) => ImageUploadService(),
);

abstract final class ImageBuckets {
  static const products = 'product-images';
  static const qris = 'qris-images';
  /// FEAT-014 — branch receipt header logo (B&W PNG, ≤576×200 px).
  static const logos = 'receipt-logos';
}
