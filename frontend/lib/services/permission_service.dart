import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// macOS native mikrofon izni yönetimi
class PermissionService {
  static const _channel = MethodChannel('com.atlas.atlasApp/permissions');

  /// Mikrofon iznini iste — izin penceresi açılır
  static Future<String> requestMicrophone() async {
    try {
      final result = await _channel.invokeMethod<String>('requestMicrophone');
      debugPrint('[Permission] Mikrofon: $result');
      return result ?? 'unknown';
    } on MissingPluginException {
      // macOS dışı platform veya channel yok
      return 'authorized';
    } catch (e) {
      debugPrint('[Permission] Hata: $e');
      return 'unknown';
    }
  }

  /// Mevcut izin durumunu kontrol et
  static Future<String> checkMicrophone() async {
    try {
      final result = await _channel.invokeMethod<String>('checkMicrophone');
      return result ?? 'unknown';
    } on MissingPluginException {
      return 'authorized';
    } catch (e) {
      return 'unknown';
    }
  }

  static bool isGranted(String status) => status == 'authorized';
}
