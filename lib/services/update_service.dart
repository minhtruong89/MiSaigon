import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Dịch vụ kiểm tra và tải cập nhật APK tự động cho Android
class UpdateService {
  static const MethodChannel _installerChannel =
      MethodChannel('com.misaigon.micharity/installer');

  final http.Client _httpClient;

  UpdateService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Lấy phiên bản hiện tại của app
  Future<String> getAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version.isNotEmpty ? info.version : '1.0.0';
    } catch (e) {
      developer.log('Lỗi lấy package info: $e', name: 'UpdateService');
      return '1.0.0';
    }
  }

  /// So sánh phiên bản máy chủ với phiên bản hiện tại (SemVer)
  /// Trả về true nếu serverVersion > currentVersion
  bool isServerVersionHigher(String? serverVersion, String currentVersion) {
    if (serverVersion == null || serverVersion.trim().isEmpty) return false;

    try {
      final serverParts = _parseVersion(serverVersion);
      final currentParts = _parseVersion(currentVersion);

      for (int i = 0; i < 3; i++) {
        final s = serverParts.length > i ? serverParts[i] : 0;
        final c = currentParts.length > i ? currentParts[i] : 0;
        if (s > c) {
          developer.log(
              '[UpdateService] Server ($serverVersion) > App ($currentVersion) -> Cần cập nhật',
              name: 'UpdateService');
          return true;
        }
        if (s < c) {
          developer.log(
              '[UpdateService] Server ($serverVersion) <= App ($currentVersion) -> Không cần cập nhật',
              name: 'UpdateService');
          return false;
        }
      }
    } catch (e) {
      developer.log('Lỗi so sánh version: $e', name: 'UpdateService');
    }

    return false;
  }

  List<int> _parseVersion(String v) {
    final clean = v.trim().split('+')[0].split('-')[0];
    return clean
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
  }

  /// Tải file APK từ URL với callback tiến trình
  Future<File?> downloadApk(
    String url, {
    required void Function(double progress, int receivedBytes, int totalBytes)
        onProgress,
  }) async {
    try {
      final uri = Uri.parse(url);
      final request = http.Request('GET', uri);
      final streamedResponse = await _httpClient.send(request);

      if (streamedResponse.statusCode != 200) {
        developer.log('HTTP ${streamedResponse.statusCode} khi tải APK',
            name: 'UpdateService');
        return null;
      }

      final totalBytes = streamedResponse.contentLength ?? -1;
      int receivedBytes = 0;

      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/update_micharity.apk');
      if (apkFile.existsSync()) {
        apkFile.deleteSync();
      }

      final sink = apkFile.openWrite();

      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          final progress = receivedBytes / totalBytes;
          onProgress(progress, receivedBytes, totalBytes);
        } else {
          onProgress(-1.0, receivedBytes, totalBytes);
        }
      }

      await sink.flush();
      await sink.close();

      return apkFile;
    } catch (e) {
      developer.log('Lỗi tải APK: $e', name: 'UpdateService');
      return null;
    }
  }

  /// Gọi Native Android Intent cài đặt file APK
  Future<bool> installApk(String filePath) async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _installerChannel.invokeMethod<bool>('installApk', {
        'filePath': filePath,
      });
      return result ?? false;
    } catch (e) {
      developer.log('Lỗi mở trình cài đặt APK: $e', name: 'UpdateService');
      return false;
    }
  }

  /// Mở màn hình Cài đặt Ứng dụng Trang chủ (Home App / Launcher) trên Android
  Future<bool> openHomeSettings() async {
    if (!Platform.isAndroid) return false;

    try {
      final result =
          await _installerChannel.invokeMethod<bool>('openHomeSettings');
      return result ?? false;
    } catch (e) {
      developer.log('Lỗi mở Cài đặt Trang chủ: $e', name: 'UpdateService');
      return false;
    }
  }
}
