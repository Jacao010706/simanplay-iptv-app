import 'dart:io';
import 'package:flutter/services.dart';

/// Detecta se o app está rodando em Android TV via PackageManager.hasSystemFeature("android.software.leanback")
class TvUtils {
  static bool? _isTV;
  static const _channel = MethodChannel('primetv/device');

  static Future<bool> isAndroidTV() async {
    if (_isTV != null) return _isTV!;
    if (!Platform.isAndroid) return _isTV = false;
    try {
      _isTV = await _channel.invokeMethod<bool>('isTvDevice') ?? false;
    } catch (_) {
      _isTV = false;
    }
    return _isTV!;
  }
}
