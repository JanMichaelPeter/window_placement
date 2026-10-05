import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:window_placement/window_placement.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('getPlacement reports fullscreen', (WidgetTester tester) async {
    final info = await WindowPlacementDetector().getPlacement();
    expect(info.placement, WindowPlacement.fullscreen);
    expect(info.isMultiWindow, isFalse);
  });

  testWidgets('onPlacementChanged emits the current placement', (
    WidgetTester tester,
  ) async {
    final info = await WindowPlacementDetector().onPlacementChanged.first;
    expect(info.placement, WindowPlacement.fullscreen);
  });
}
