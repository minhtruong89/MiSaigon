import 'dart:developer' as developer;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Dịch vụ phát âm thanh BÍP khi quét QR thành công
class SoundService {
  static const MethodChannel _nativeAudioChannel =
      MethodChannel('com.misaigon.micharity/audio');

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
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
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
    // 1. Phản hồi rung
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}

    // 2. Gọi Native Audio (AudioTrack trực tiếp phát sóng âm ra Loa Ngoài)
    try {
      await _nativeAudioChannel.invokeMethod<bool>('playBeep');
    } catch (e) {
      developer.log('Native beep error: $e', name: 'SoundService');
    }

    // 3. Dự phòng song song SystemSound
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}

    // 4. Dự phòng AudioPlayer
    try {
      await init();
      await _player.stop();
      await _player.play(AssetSource('audio/qr_success.wav'), volume: 1.0);
    } catch (e) {
      developer.log('AudioPlayer error: $e', name: 'SoundService');
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
