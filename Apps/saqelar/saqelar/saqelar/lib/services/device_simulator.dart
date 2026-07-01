import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/telemetry.dart';

/// Telemetry source. Runs a local simulation by default and, when an MQTT
/// broker + topic are configured, subscribes and shows real device data
/// (device.telemetry.v1). The control loop mirrors `Anggie.ino` so both
/// halves stay in sync.
///
/// ponytail: one ChangeNotifier owns both the simulation and the MQTT link.
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
    // Automatic by default: connect to saved or default broker/topic on launch,
    // unless the user explicitly disconnected before.
    final b = p.getString('mqttBroker') ?? FirmwareConstants.mqttBroker;
    final t = p.getString('mqttTopic') ?? FirmwareConstants.mqttTelemetryTopic;
    final auto = p.getBool('mqttAuto') ?? true;
    notifyListeners();
    if (auto && b.isNotEmpty && t.isNotEmpty) connect(b, t);
  }

  /// Fired when the live link flips (true = device data, false = simulator),
  /// so the UI can show a connect / fallback notification.
  void Function(bool live)? onLiveChange;
  void _setLive(bool v) {
    if (isLive != v) {
      isLive = v;
      onLiveChange?.call(v);
    }
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

  // ---- MQTT live link ----
  String? broker; // null => simulation mode
  String? topic; // telemetry topic to subscribe
  String get commandTopic =>
      (topic ?? FirmwareConstants.mqttTelemetryTopic).contains('/telemetry')
          ? (topic ?? '').replaceAll('/telemetry', '/command')
          : '${topic ?? ''}/command';
  bool isLive = false; // true while fresh telemetry is arriving
  String connectionStatus = 'Simulator';
  MqttServerClient? _mqtt;
  DateTime? _lastMsg;

  bool get isSimulated => broker == null;

  /// Connect to an MQTT broker and subscribe to a telemetry topic. Device data
  /// then replaces the simulation. Persists so it reconnects on next launch.
  Future<void> connect(String brokerHost, String telemetryTopic) async {
    broker = brokerHost.trim();
    topic = telemetryTopic.trim();
    connectionStatus = 'Menyambung ke $broker ...';
    _prefs?.setString('mqttBroker', broker!);
    _prefs?.setString('mqttTopic', topic!);
    _prefs?.setBool('mqttAuto', true);
    notifyListeners();

    await _disposeClient();
    final clientId =
        'saqelar-${DateTime.now().millisecondsSinceEpoch % 100000}';
    final c = MqttServerClient(broker!, clientId)
      ..port = FirmwareConstants.mqttPort
      ..keepAlivePeriod = 30
      ..autoReconnect = true
      ..logging(on: false)
      ..onDisconnected = _onDisconnected
      ..onConnected = _onConnected;
    _mqtt = c;
    try {
      await c.connect();
    } catch (e) {
      connectionStatus = 'Gagal konek broker';
      _setLive(false);
      notifyListeners();
      return;
    }
    c.subscribe(topic!, MqttQos.atMostOnce);
    c.updates?.listen(_onMessage);
  }

  void _onConnected() {
    connectionStatus = 'Terhubung, menunggu data ...';
    if (topic != null) _mqtt?.subscribe(topic!, MqttQos.atMostOnce);
    notifyListeners();
  }

  void _onDisconnected() {
    _setLive(false);
    connectionStatus = 'Broker terputus';
    notifyListeners();
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> events) {
    final rec = events.first.payload as MqttPublishMessage;
    final text =
        MqttPublishPayload.bytesToStringAsString(rec.payload.message);
    try {
      final json = jsonDecode(text) as Map<String, dynamic>;
      final t = Telemetry.fromJson(json);
      _lastMsg = DateTime.now();
      _setLive(true);
      connectionStatus = 'Device live · $broker';
      _latest = t;
      _luxHistory.add(t.lux);
      _powerHistory.add(t.powerW);
      if (_luxHistory.length > _historyLen) _luxHistory.removeAt(0);
      if (_powerHistory.length > _historyLen) _powerHistory.removeAt(0);
      if (t.isFault && _lastSafetyState != 'fault') onFaultEnter?.call();
      _lastSafetyState = t.safetyState;
      notifyListeners();
    } catch (_) {
      // Ignore malformed payloads; keep last good telemetry.
    }
  }

  /// Publish a command to the device (future control feature).
  void publishCommand(Map<String, dynamic> command) {
    final c = _mqtt;
    if (c == null || c.connectionStatus?.state != MqttConnectionState.connected) {
      return;
    }
    final builder = MqttClientPayloadBuilder()..addString(jsonEncode(command));
    c.publishMessage(commandTopic, MqttQos.atMostOnce, builder.payload!);
  }

  Future<void> _disposeClient() async {
    try {
      _mqtt?.disconnect();
    } catch (_) {}
    _mqtt = null;
  }

  void disconnect() {
    _disposeClient();
    broker = null;
    topic = null;
    _setLive(false);
    connectionStatus = 'Simulator';
    _prefs?.remove('mqttBroker');
    _prefs?.remove('mqttTopic');
    _prefs?.setBool('mqttAuto', false); // respect explicit disconnect
    notifyListeners();
  }

  // ---- Operator-settable controls (advisory; safety still wins) ----
  DeviceMode mode = DeviceMode.auto;
  double targetLux = FirmwareConstants.defaultTargetLux;
  int manualDimmer = 60;
  double kp = FirmwareConstants.kp;
  double ki = FirmwareConstants.ki;
  double kd = FirmwareConstants.kd;

  bool simulateDaylight = false;
  bool simulateOvercurrent = false;

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
    targetLux = v.clamp(0, FirmwareConstants.maxTargetLux);
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
    // Drop out of live mode if telemetry went stale (broker or device gone).
    if (isLive &&
        _lastMsg != null &&
        DateTime.now().difference(_lastMsg!).inSeconds > 6) {
      _setLive(false);
      connectionStatus = 'Device diam, kembali ke simulator';
    }
    if (isLive) return; // live device drives the data; skip simulation

    final drift = sin(_seq / 30.0) * 300;
    _ldr = simulateDaylight
        ? 3200 + _rng.nextInt(200)
        : (1700 + drift + _rng.nextInt(120)).round().clamp(0, 4095);

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
      var error = targetLux - _lux;
      if (_ldr < FirmwareConstants.ldrFeedforwardRaw) {
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

    final ambientLux = (_ldr / 4095) * 80;
    final driven = _dimmer / FirmwareConstants.dimmerMaxPct * 620;
    final targetPhysical = relay ? ambientLux + driven : ambientLux;
    _lux += (targetPhysical - _lux) * 0.35 + (_rng.nextDouble() - 0.5) * 6;
    if (_lux < 0) _lux = 0;

    var currentMa = simulateOvercurrent
        ? estCurrent
        : (relay ? estCurrent + (_rng.nextDouble() - 0.5) * 10 : 0.0);
    if (currentMa < FirmwareConstants.currentFloorMa) currentMa = 0;
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
    _disposeClient();
    super.dispose();
  }
}
