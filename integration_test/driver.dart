import 'package:integration_test/integration_test_driver.dart';

/// Attach to an explicitly installed/running verification APK. This avoids
/// the Flutter installer uninstall fallback during persistence verification.
Future<void> main() => integrationDriver();
