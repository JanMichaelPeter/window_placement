import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'window_placement_pigeon.dart';
import 'src/window_placement_info.dart';

/// The interface that platform implementations of window_placement extend.
abstract class WindowPlacementPlatform extends PlatformInterface {
  /// Constructs a WindowPlacementPlatform.
  WindowPlacementPlatform() : super(token: _token);

  static final Object _token = Object();

  static WindowPlacementPlatform _instance = PigeonWindowPlacement();

  /// The default instance of [WindowPlacementPlatform] to use.
  ///
  /// Defaults to [PigeonWindowPlacement].
  static WindowPlacementPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [WindowPlacementPlatform] when
  /// they register themselves.
  static set instance(WindowPlacementPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Returns the current placement of the app window on the display.
  Future<WindowPlacementInfo> getPlacement() {
    throw UnimplementedError('getPlacement() has not been implemented.');
  }

  /// Emits the current placement on listen and whenever it changes.
  Stream<WindowPlacementInfo> get onPlacementChanged {
    throw UnimplementedError('onPlacementChanged has not been implemented.');
  }
}
