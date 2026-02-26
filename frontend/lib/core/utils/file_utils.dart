import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class FileUtils {
  static String? getFileNameFromUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        return segments.last;
      }
    } catch (e) {
      print('Error parsing URL: $e');
    }
    return 'CV uploaded';
  }

  static Future<bool> openFile(String url) async {
    try {
      final uri = Uri.parse(url);
      print('  Opening file: $url');

      if (await canLaunchUrl(uri)) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      }

      return await launchUrl(
        uri,
        mode: LaunchMode.inAppWebView,
      );
    } catch (e) {
      print('   Error opening file: $e');
      return false;
    }
  }

  static Future<bool> downloadFile(String url,
      {Function(double)? onProgress}) async {
    try {
      print('  Starting download: $url');

      if (Platform.isAndroid) {
        if (await Permission.manageExternalStorage.isGranted) {
          print('    Manage storage permission already granted');
        } else {
          print(' Requesting manage storage permission...');
          var status = await Permission.manageExternalStorage.request();
          if (!status.isGranted) {
            print('   Manage storage permission denied');

            status = await Permission.storage.request();
            if (!status.isGranted) {
              print('   Storage permission denied');
              return false;
            }
          }
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

      if (directory == null) {
        print('   Could not access download directory');
        return false;
      }

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      String fileName = getFileNameFromUrl(url) ??
          'cv_${DateTime.now().millisecondsSinceEpoch}.pdf';
      String filePath = '${directory.path}/$fileName';

      print('📁 Saving to: $filePath');

      Dio dio = Dio();

      await dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            double progress = received / total;
            print(
                '  Download progress: ${(progress * 100).toStringAsFixed(1)}%');
            if (onProgress != null) {
              onProgress(progress);
            }
          }
        },
      );

      print('    Download completed: $filePath');

      if (Platform.isAndroid) {
        await launchUrl(
          Uri.parse(
              'content://com.android.externalstorage.documents/document/primary:Download'),
          mode: LaunchMode.externalApplication,
        );
      }

      return true;
    } catch (e) {
      print('   Error downloading file: $e');
      return false;
    }
  }

  static String getFileExtension(String url) {
    try {
      final fileName = getFileNameFromUrl(url) ?? '';
      final parts = fileName.split('.');
      if (parts.length > 1) {
        return parts.last.toLowerCase();
      }
    } catch (e) {
      print('Error getting file extension: $e');
    }
    return 'pdf';
  }

  static IconData getFileIcon(String url) {
    final ext = getFileExtension(url);
    switch (ext) {
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
    final ext = getFileExtension(url);
    switch (ext) {
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
