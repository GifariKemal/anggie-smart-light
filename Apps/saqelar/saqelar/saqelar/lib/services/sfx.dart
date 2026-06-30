import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Tiny UI sound + haptics helper. ponytail: one reusable player, fire-and-
/// forget, wrapped so a missing audio backend never breaks the UI.
class Sfx {
  Sfx._();
  static final Sfx instance = Sfx._();

  final AudioPlayer _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  bool muted = false;

  Future<void> _play(String file) async {
    if (muted) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sfx/$file'), volume: 0.6);
    } catch (_) {
      // No audio backend available — haptics still carry the feedback.
    }
  }

  void tap() {
    HapticFeedback.selectionClick();
    _play('tap.ogg');
  }

  void select() {
    HapticFeedback.selectionClick();
    _play('select.ogg');
  }

  void toggleOn() {
    HapticFeedback.lightImpact();
    _play('toggle_on.ogg');
  }

  void toggleOff() {
    HapticFeedback.lightImpact();
    _play('toggle_off.ogg');
  }

  void success() {
    HapticFeedback.mediumImpact();
    _play('success.ogg');
  }

  void alert() {
    HapticFeedback.heavyImpact();
    _play('alert.ogg');
  }
}
