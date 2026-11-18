/// Compile-time configuration, supplied with `--dart-define`.
///
/// flutter run -d chrome --dart-define=USE_FIREBASE=true
abstract final class Env {
  /// false => in-memory sample data, no backend required.
  static const bool useFirebase = bool.fromEnvironment('USE_FIREBASE');
}

abstract final class AdminConfig {
  static const String appName = 'mart2door admin';

  /// Sample-data sign-in.
  static const String demoEmail = 'admin@mart2door.com';
  static const String demoPassword = 'admin123';
}
