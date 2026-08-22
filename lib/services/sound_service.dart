import 'dart:developer' as developer;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Dịch vụ phát âm thanh BÍP khi quét QR thành công
class SoundService {
  AudioPlayer? _audioPlayer;
  bool _isInitialized = false;

  SoundService({AudioPlayer? audioPlayer}) {
    _audioPlayer = audioPlayer;
  }

  AudioPlayer get _player => _audioPlayer ??= AudioPlayer();

  /// Khởi tạo và cấu hình audio player
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await _player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {
              AVAudioSessionOptions.mixWithOthers,
              AVAudioSessionOptions.duckOthers,
            },
          ),
        ),
      );
      await _player.setVolume(1.0);
      _isInitialized = true;
    } catch (e) {
      developer.log('Lỗi khởi tạo AudioContext: $e', name: 'SoundService');
    }
  }

  /// Phát đúng 1 tiếng bíp lớn khi QR hợp lệ
  Future<void> playSuccessBeep() async {
    try {
      await init();
      // Dừng âm thanh cũ nếu đang phát để phát tiếng bíp mới dứt khoát
      await _player.stop();
      await _player.play(AssetSource('audio/qr_success.wav'), volume: 1.0);
    } catch (e) {
      developer.log('Lỗi phát âm thanh WAV: $e, sử dụng SystemSound fallback',
          name: 'SoundService');
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (fallbackError) {
        developer.log('Lỗi fallback SystemSound: $fallbackError',
            name: 'SoundService');
      }
    }
  }

  /// Giải phóng tài nguyên
  Future<void> dispose() async {
    try {
      if (_audioPlayer != null) {
        await _player.stop();
        await _player.dispose();
      }
    } catch (e) {
      developer.log('Lỗi dispose AudioPlayer: $e', name: 'SoundService');
    }
  }
}
