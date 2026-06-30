import 'package:flutter/widgets.dart';

import 'device_simulator.dart';

/// Exposes the [DeviceSimulator] to the widget tree and rebuilds dependents on
/// every telemetry tick. ponytail: built-in InheritedNotifier, no provider dep.
class DeviceScope extends InheritedNotifier<DeviceSimulator> {
  const DeviceScope({
    super.key,
    required DeviceSimulator simulator,
    required super.child,
  }) : super(notifier: simulator);

  static DeviceSimulator of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<DeviceScope>();
    assert(scope?.notifier != null, 'DeviceScope not found in tree');
    return scope!.notifier!;
  }
}
