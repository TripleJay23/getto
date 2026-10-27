import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/routing/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Include the bundled SIL OFL license in Flutter's application licenses.
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(<String>['Manrope'], license);
  });

  final router = createAppRouter();
  runApp(ProviderScope(child: GettoApp(router: router)));
}
