import 'package:flutter/foundation.dart';

enum Environment { dev, prod }

class AppEnvironment {
  /// By default:
  /// - `kDebugMode` (when running `flutter run` or in IDE) -> connects to [Environment.dev]
  /// - `kReleaseMode` (when building for TestFlight / Google Play) -> connects to [Environment.prod]
  ///
  /// You can also manually override by changing [_manualOverride].
  static Environment? _manualOverride;

  static Environment get current {
    if (_manualOverride != null) return _manualOverride!;
    return kDebugMode ? Environment.dev : Environment.prod;
  }

  static bool get isDev => current == Environment.dev;
  static bool get isProd => current == Environment.prod;

  static String get name => isDev ? 'DEVELOPMENT (Dev)' : 'PRODUCTION (Prod)';

  static void setEnvironment(Environment? env) {
    _manualOverride = env;
  }
}

