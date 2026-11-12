import 'package:flutter/material.dart';
import 'package:window_placement/window_placement.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: StreamBuilder<WindowEnvironment>(
            stream: WindowPlacementDetector().onEnvironmentChanged,
            builder: (context, snapshot) {
              final environment = snapshot.data;
              final info =
                  environment?.placement ?? WindowPlacementInfo.unknown;
              final traits = environment?.iosTraits;
              final windowBounds = info.windowBounds;
              final screenBounds = info.screenBounds;
              String n(double v) => v.toStringAsFixed(1);
              String b(bool v) => v ? 'yes' : 'no';
              final traitsLine = traits == null
                  ? 'no iOS traits'
                  : 'size class H ${traits.horizontalSizeClass.name}  '
                        'V ${traits.verticalSizeClass.name}  '
                        'idiom ${traits.interfaceIdiom.name}';
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Displayed: ${info.placement.name}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'window x ${n(windowBounds.left)}  y ${n(windowBounds.top)}  '
                    'w ${n(windowBounds.width)}  h ${n(windowBounds.height)}\n'
                    'gaps L ${n(windowBounds.left)}  T ${n(windowBounds.top)}  '
                    'R ${n(screenBounds.right - windowBounds.right)}  B ${n(screenBounds.bottom - windowBounds.bottom)}\n'
                    'touches L ${b(info.touchesLeftEdge)}  '
                    'T ${b(info.touchesTopEdge)}  '
                    'R ${b(info.touchesRightEdge)}  '
                    'B ${b(info.touchesBottomEdge)}\n'
                    'screen ${n(screenBounds.width)} × ${n(screenBounds.height)}\n'
                    '$traitsLine\n'
                    'updated ${DateTime.now().toIso8601String().substring(11, 19)}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
