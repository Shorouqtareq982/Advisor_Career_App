// lib/core/utils/file_utils.dart
// الحل النهائي لمشكلة اسم الـ CV

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class FileUtils {
  /// UUID pattern للتعرف على الـ UUIDs
  static final _uuidPattern = RegExp(
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
  );

  /// استخرج اسم الملف الأصلي من الـ URL
  static String? getFileNameFromUrl(String? url) {
    if (url == null || url.isEmpty) return null;

    try {
      final uri = Uri.parse(url);

      // ── Case 1: URL مع ?original= param (الكود الجديد) ──────────────────
      // مثال: .../1771274419752.pdf?original=Ranim_CV.pdf
      final originalParam = uri.queryParameters['original'];
      if (originalParam != null && originalParam.isNotEmpty) {
        return Uri.decodeComponent(originalParam);
      }

      // ── Case 2: Supabase Storage URL (الكود القديم) ───────────────────────
      // مثال: .../cvs/UUID/cv_UUID_timestamp.pdf
      if (uri.host.contains('supabase.co') ||
          uri.host.contains('supabase.in')) {
        final segments = uri.pathSegments;
        if (segments.isNotEmpty) {
          final fileName = segments.last;
          final ext =
              fileName.contains('.') ? '.${fileName.split('.').last}' : '.pdf';

          // لو الاسم بيبدأ بـ cv_ وبعده UUID → اسم قديم → رجّع "CV"
          // Pattern: cv_UUID_timestamp.ext
          if (RegExp(r'^cv_[0-9a-fA-F\-]+_\d+\.\w+$').hasMatch(fileName)) {
            return 'CV$ext';
          }

          // لو الاسم مجرد timestamp → رجّع "CV"
          final nameOnly = fileName.contains('.')
              ? fileName.substring(0, fileName.lastIndexOf('.'))
              : fileName;
          if (RegExp(r'^\d+$').hasMatch(nameOnly)) {
            return 'CV$ext';
          }

          // لو فيه UUID في الاسم → رجّع "CV"
          if (_uuidPattern.hasMatch(nameOnly)) {
            return 'CV$ext';
          }

          // غير كده → الاسم صح، ارجعه
          return fileName;
        }
      }

      // ── Case 3: Cloudinary URL ────────────────────────────────────────────
      // مثال: https://res.cloudinary.com/.../cv_UUID_Ranim_CV.pdf
      if (uri.host.contains('cloudinary.com')) {
        final segments = uri.pathSegments;
        if (segments.isNotEmpty) {
          final lastSegment = segments.last;
          final dotIdx = lastSegment.lastIndexOf('.');
          final nameOnly =
              dotIdx > 0 ? lastSegment.substring(0, dotIdx) : lastSegment;
          final ext = dotIdx > 0 ? lastSegment.substring(dotIdx) : '.pdf';

          // Pattern: cv_UUID_originalname.ext
          final cvUuidMatch = RegExp(
            r'^cv_[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}_(.+)$',
          ).firstMatch(nameOnly);

          if (cvUuidMatch != null) {
            final extracted = cvUuidMatch.group(1)!;
            return extracted.isNotEmpty ? '$extracted$ext' : 'CV$ext';
          }

          // لو مجرد UUID أو timestamp
          if (_uuidPattern.hasMatch(nameOnly) ||
              RegExp(r'^\d+$').hasMatch(nameOnly)) {
            return 'CV$ext';
          }

          return lastSegment;
        }
      }

      // ── Case 4: أي URL تاني ───────────────────────────────────────────────
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        final fileName = segments.last.split('?').first;
        if (fileName.isNotEmpty) return fileName;
      }
    } catch (e) {
      print('Error parsing file URL: $e');
    }

    return 'CV';
  }

  static Future<bool> openFile(String url) async {
    try {
      final cleanUrl = url.split('?original=').first;
      final uri = Uri.parse(cleanUrl);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return await launchUrl(uri, mode: LaunchMode.inAppWebView);
    } catch (e) {
      print('Error opening file: $e');
      return false;
    }
  }

  static Future<bool> downloadFile(
    String url, {
    Function(double)? onProgress,
  }) async {
    try {
      if (Platform.isAndroid) {
        var status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) return false;
        }
      }

      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
          if (directory != null) {
            directory = Directory('${directory.path}/Download');
          }
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) return false;
      if (!await directory.exists()) await directory.create(recursive: true);

      final fileName = getFileNameFromUrl(url) ??
          'cv_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${directory.path}/$fileName';

      // شيل الـ ?original= قبل الـ download
      final downloadUrl =
          url.contains('?original=') ? url.split('?original=').first : url;

      final dio = Dio();
      await dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

      if (Platform.isAndroid) {
        await launchUrl(
          Uri.parse(
              'content://com.android.externalstorage.documents/document/primary:Download'),
          mode: LaunchMode.externalApplication,
        );
      }

      return true;
    } catch (e) {
      print('Error downloading file: $e');
      return false;
    }
  }

  static String getFileExtension(String url) {
    try {
      final fileName = getFileNameFromUrl(url) ?? '';
      final parts = fileName.split('.');
      if (parts.length > 1) return parts.last.toLowerCase();
    } catch (_) {}
    return 'pdf';
  }

  static IconData getFileIcon(String url) {
    switch (getFileExtension(url)) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  static Color getFileColor(String url) {
    switch (getFileExtension(url)) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
