import 'package:flutter_test/flutter_test.dart';
import 'package:saqelar/app/app_theme.dart';
import 'package:saqelar/models/telemetry.dart';

Telemetry _sample({
  String safety = 'ok',
  double lux = 250,
  double target = 500,
}) {
  return Telemetry(
    seq: 1,
    timestamp: DateTime(2026),
    mode: 'auto',
    relayOn: safety == 'ok',
    safetyState: safety,
    faultReason: null,
    lux: lux,
    targetLux: target,
    ldrRaw: 1800,
    currentMa: 500,
    powerW: 110,
    dimmerPct: 60,
    kp: FirmwareConstants.kp,
    ki: FirmwareConstants.ki,
    kd: FirmwareConstants.kd,
    pidOutput: 0,
    uptime: Duration.zero,
  );
}

void main() {
  group('Telemetry contract', () {
    test('safety flags reflect safetyState', () {
      expect(_sample(safety: 'ok').isOk, isTrue);
      expect(_sample(safety: 'fault').isFault, isTrue);
      expect(_sample(safety: 'standby').isStandby, isTrue);
      expect(_sample(safety: 'fault').isOk, isFalse);
    });

    test('luxProgress is the clamped ratio toward target', () {
      expect(_sample(lux: 250, target: 500).luxProgress, closeTo(0.5, 1e-9));
      expect(_sample(lux: 600, target: 500).luxProgress, 1.0); // clamped
      expect(_sample(lux: 100, target: 0).luxProgress, 0.0); // guard /0
    });
  });

  test('safetyColor maps to the firmware status palette', () {
    expect(AppTheme.safetyColor('ok'), AppTheme.accent);
    expect(AppTheme.safetyColor('standby'), AppTheme.warning);
    expect(AppTheme.safetyColor('fault'), AppTheme.danger);
  });

  test('Telemetry.fromJson parses a firmware device.telemetry.v1 payload', () {
    final t = Telemetry.fromJson({
      'schema': 'device.telemetry.v1',
      'deviceId': 'anggie-001',
      'seq': 12,
      'ts': '2026-07-01T08:30:00+07:00',
      'mode': 'night',
      'relayOn': true,
      'safetyState': 'ok',
      'faultReason': null,
      'lux': 512.5,
      'targetLux': 500,
      'ldrRaw': 1850,
      'currentMa': 410.2,
      'powerW': 90.2,
      'dimmerPct': 40,
      'pid': {'kp': 0.15, 'ki': 0.05, 'kd': 0.01, 'output': -1.2},
      'uptimeMs': 65000,
      'firmware': '0.2.0',
    });
    expect(t.seq, 12);
    expect(t.mode, 'night');
    expect(t.relayOn, isTrue);
    expect(t.lux, closeTo(512.5, 1e-9));
    expect(t.dimmerPct, 40);
    expect(t.kp, 0.15);
    expect(t.pidOutput, closeTo(-1.2, 1e-9));
    expect(t.uptime.inSeconds, 65);
    expect(t.firmware, '0.2.0');
    expect(t.isOk, isTrue);
  });
}
