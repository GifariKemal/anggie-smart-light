import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/telemetry.dart';

/// Drives dummy-but-physically-plausible telemetry that obeys the same control
/// + safety rules as `Anggie.ino`. No network, no auth — pure local simulation
/// so the UI behaves exactly like it will once wired to a real ESP32.
///
/// ponytail: a Timer + a tiny PID loop is enough; no state-mgmt package.
class DeviceSimulator extends ChangeNotifier {
  DeviceSimulator() {
    _start = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 800), (_) => _tick());
    _tick();
    _loadPrefs();
  }

  SharedPreferences? _prefs;

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    _prefs = p;
    mode = DeviceMode.values[(p.getInt('mode') ?? mode.index).clamp(
      0,
      DeviceMode.values.length - 1,
    )];
    targetLux = p.getDouble('targetLux') ?? targetLux;
    manualDimmer = p.getInt('manualDimmer') ?? manualDimmer;
    kp = p.getDouble('kp') ?? kp;
    ki = p.getDouble('ki') ?? ki;
    kd = p.getDouble('kd') ?? kd;
    final savedUrl = p.getString('deviceUrl');
    notifyListeners();
    if (savedUrl != null && savedUrl.isNotEmpty) connect(savedUrl);
  }

  void _save() {
    final p = _prefs;
    if (p == null) return;
    p.setInt('mode', mode.index);
    p.setDouble('targetLux', targetLux);
    p.setInt('manualDimmer', manualDimmer);
    p.setDouble('kp', kp);
    p.setDouble('ki', ki);
    p.setDouble('kd', kd);
  }

  // ---- Live device link (HTTP polling of GET <url>/telemetry) ----
  String? deviceUrl; // null => simulation mode
  bool isLive = false; // true when last poll succeeded
  String connectionStatus = 'Simulator';
  Timer? _pollTimer;

  bool get isSimulated => deviceUrl == null;

  /// Point the app at a real ESP32 base URL, e.g. http://192.168.1.50 or
  /// http://saqelar.local. Persists and starts polling; data replaces the sim.
  void connect(String url) {
    final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    deviceUrl = clean;
    connectionStatus = 'Menyambung ke device…';
    _prefs?.setString('deviceUrl', clean);
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
    _poll();
    notifyListeners();
  }

  void disconnect() {
    _pollTimer?.cancel();
    _pollTimer = null;
    deviceUrl = null;
    isLive = false;
    connectionStatus = 'Simulator';
    _prefs?.remove('deviceUrl');
    notifyListeners();
  }

  Future<void> _poll() async {
    final url = deviceUrl;
    if (url == null) return;
    try {
      final res = await http
          .get(Uri.parse('$url/telemetry'))
          .timeout(const Duration(seconds: 2));
      if (res.statusCode != 200) {
        _markOffline('HTTP ${res.statusCode}');
        return;
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final t = Telemetry.fromJson(json);
      isLive = true;
      connectionStatus = 'Device live · $url';
      _latest = t;
      _luxHistory.add(t.lux);
      _powerHistory.add(t.powerW);
      if (_luxHistory.length > _historyLen) _luxHistory.removeAt(0);
      if (_powerHistory.length > _historyLen) _powerHistory.removeAt(0);
      if (t.isFault && _lastSafetyState != 'fault') onFaultEnter?.call();
      _lastSafetyState = t.safetyState;
      notifyListeners();
    } catch (e) {
      _markOffline('Tidak terhubung');
    }
  }

  void _markOffline(String reason) {
    if (isLive || connectionStatus != 'Device offline · $reason') {
      isLive = false;
      connectionStatus = 'Device offline · $reason';
      notifyListeners();
    }
  }

  // ---- Operator-settable controls (advisory; safety still wins) ----
  DeviceMode mode = DeviceMode.auto;
  double targetLux = FirmwareConstants.defaultTargetLux;
  int manualDimmer = 60; // used only in manual mode
  double kp = FirmwareConstants.kp;
  double ki = FirmwareConstants.ki;
  double kd = FirmwareConstants.kd;

  // Demo scenario toggles so reviewers can see standby/fault live.
  bool simulateDaylight = false; // forces LDR above daylight threshold
  bool simulateOvercurrent = false; // forces current past safe limit

  /// Fired once when the device transitions INTO a fault (for alarm fx).
  /// Kept out of widget build() so the alarm never double-fires on rebuild.
  void Function()? onFaultEnter;
  String _lastSafetyState = 'ok';

  // ---- Internal sim state ----
  late final DateTime _start;
  Timer? _timer;
  final _rng = Random(7);
  int _seq = 0;
  double _lux = 120;
  double _dimmer = 0;
  double _integral = 0;
  double _lastError = 0;
  double _pidOutput = 0;
  int _ldr = 1800;

  final List<double> _luxHistory = [];
  final List<double> _powerHistory = [];
  static const int _historyLen = 48;

  Telemetry? _latest;
  Telemetry? get latest => _latest;
  List<double> get luxHistory => List.unmodifiable(_luxHistory);
  List<double> get powerHistory => List.unmodifiable(_powerHistory);

  void setMode(DeviceMode m) {
    mode = m;
    _save();
    notifyListeners();
  }

  void setTargetLux(double v) {
    targetLux = v.clamp(0, 1000);
    _save();
    notifyListeners();
  }

  void setManualDimmer(int v) {
    manualDimmer = v.clamp(0, FirmwareConstants.dimmerMaxPct);
    _save();
    notifyListeners();
  }

  void setPid({double? kp, double? ki, double? kd}) {
    this.kp = kp ?? this.kp;
    this.ki = ki ?? this.ki;
    this.kd = kd ?? this.kd;
    _save();
    notifyListeners();
  }

  void toggleDaylight(bool v) {
    simulateDaylight = v;
    notifyListeners();
  }

  void toggleOvercurrent(bool v) {
    simulateOvercurrent = v;
    notifyListeners();
  }

  void _tick() {
    if (deviceUrl != null) return; // live device drives data; skip simulation

    // Ambient light: gentle drift, or forced daylight for the demo scenario.
    final drift = sin(_seq / 30.0) * 300;
    _ldr = simulateDaylight
        ? 3200 + _rng.nextInt(200)
        : (1700 + drift + _rng.nextInt(120)).round().clamp(0, 4095);

    // ---- Safety / mode state machine: same priority as the firmware loop() ----
    // Estimate current first (depends on previous dimmer) for the OC check.
    final estCurrent = simulateOvercurrent
        ? 5200 + _rng.nextDouble() * 200
        : _dimmer / FirmwareConstants.dimmerMaxPct * 700;

    final hour = DateTime.now().hour;
    final nightActive = hour >= FirmwareConstants.nightStartHour ||
        hour < FirmwareConstants.nightEndHour;

    String safety;
    String? fault;
    bool relay;
    bool night = false;
    if (mode == DeviceMode.off) {
      safety = 'standby';
      fault = null;
      relay = false;
    } else if (estCurrent > FirmwareConstants.maxSafeCurrentMa) {
      safety = 'fault';
      fault = 'OVERCURRENT';
      relay = false;
    } else if (nightActive && mode == DeviceMode.auto) {
      safety = 'ok';
      fault = null;
      relay = true;
      night = true;
    } else if (_ldr > FirmwareConstants.ldrDaylightRaw) {
      safety = 'standby';
      fault = 'DAYLIGHT_STANDBY';
      relay = false;
    } else {
      safety = 'ok';
      fault = null;
      relay = true;
    }

    // ---- Dimmer drive ----
    if (!relay) {
      _dimmer = 0;
      _integral = 0;
      _pidOutput = 0;
    } else if (night) {
      _dimmer = FirmwareConstants.nightDimmerPct.toDouble();
      _pidOutput = 0;
      _integral = 0;
    } else if (mode == DeviceMode.manual) {
      _dimmer = manualDimmer.toDouble();
      _pidOutput = 0;
    } else {
      // Auto: discrete PID nudging dimmer toward target lux (mirrors firmware).
      var error = targetLux - _lux;
      if (_ldr < FirmwareConstants.ldrFeedforwardRaw) {
        // Dynamic feed-forward (mirrors firmware map(0..1000 -> 100..0)).
        error += (FirmwareConstants.ldrFeedforwardRaw - _ldr) /
            FirmwareConstants.ldrFeedforwardRaw *
            100;
      }
      _integral = (_integral + error * 0.2).clamp(-100, 100);
      final derivative = (error - _lastError) / 0.2;
      _pidOutput = kp * error + ki * _integral + kd * derivative;
      _dimmer = (_dimmer + _pidOutput).clamp(
        0,
        FirmwareConstants.dimmerMaxPct.toDouble(),
      );
      _lastError = error;
    }

    // ---- Plant: lux responds to dimmer + ambient, with a little noise ----
    final ambientLux = (_ldr / 4095) * 80;
    final driven = _dimmer / FirmwareConstants.dimmerMaxPct * 620;
    final targetPhysical = relay ? ambientLux + driven : ambientLux;
    _lux += (targetPhysical - _lux) * 0.35 + (_rng.nextDouble() - 0.5) * 6;
    if (_lux < 0) _lux = 0;

    // Overcurrent demo reports the offending spike even as the relay trips
    // (mirrors firmware reading the high mA on the cycle it cuts power).
    var currentMa = simulateOvercurrent
        ? estCurrent
        : (relay ? estCurrent + (_rng.nextDouble() - 0.5) * 10 : 0.0);
    if (currentMa < FirmwareConstants.currentFloorMa) currentMa = 0; // fw floor
    final powerW = currentMa / 1000.0 * FirmwareConstants.mainsVoltage;

    _luxHistory.add(_lux);
    _powerHistory.add(powerW);
    if (_luxHistory.length > _historyLen) _luxHistory.removeAt(0);
    if (_powerHistory.length > _historyLen) _powerHistory.removeAt(0);

    _latest = Telemetry(
      seq: ++_seq,
      timestamp: DateTime.now(),
      mode: night ? 'night' : mode.wire,
      relayOn: relay,
      safetyState: safety,
      faultReason: fault,
      lux: _lux,
      targetLux: targetLux,
      ldrRaw: _ldr,
      currentMa: currentMa,
      powerW: powerW,
      dimmerPct: _dimmer.round(),
      kp: kp,
      ki: ki,
      kd: kd,
      pidOutput: _pidOutput,
      uptime: DateTime.now().difference(_start),
    );

    if (safety == 'fault' && _lastSafetyState != 'fault') onFaultEnter?.call();
    _lastSafetyState = safety;

    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }
}
