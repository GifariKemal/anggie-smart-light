import 'package:flutter/material.dart';
import 'package:saqelar/app/app_theme.dart';
import 'package:saqelar/services/device_scope.dart';
import 'package:saqelar/services/device_simulator.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const Saqelar());
}

class Saqelar extends StatefulWidget {
  const Saqelar({super.key});

  @override
  State<Saqelar> createState() => _SaqelarState();
}

class _SaqelarState extends State<Saqelar> {
  final DeviceSimulator _simulator = DeviceSimulator();

  @override
  void dispose() {
    _simulator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DeviceScope(
      simulator: _simulator,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Saqelar IoT',
        theme: AppTheme.dark(),
        // Clamp runaway font scaling so the dense HUD numerics never overflow.
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: child!,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
