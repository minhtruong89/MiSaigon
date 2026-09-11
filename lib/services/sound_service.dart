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

  /// Phát âm thanh Nốt Sol (G4: 392Hz) khi Quét Thẻ/Mã thành công
  Future<void> playScanSuccessBeep() async {
    // 1. Phản hồi rung haptic
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}

    // 2. Gọi Native Audio (Kích hoạt Vibrator phần cứng + AudioTrack Nốt Sol)
    try {
      await _nativeAudioChannel.invokeMethod<bool>('playScanBeep');
    } catch (e) {
      developer.log('Native scan beep error: $e', name: 'SoundService');
    }

    // 3. Dự phòng song song SystemSound
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}

    // 4. Dự phòng AudioPlayer với file scan_success.wav (Nốt Sol)
    try {
      await init();
      await _player.stop();
      await _player.play(AssetSource('audio/scan_success.wav'), volume: 1.0);
    } catch (e) {
      developer.log('AudioPlayer error: $e', name: 'SoundService');
    }
  }

  /// Phát âm thanh Nốt Đô (C4: 261Hz) khi Xác nhận suất ăn thành công
  Future<void> playConfirmSuccessBeep() async {
    // 1. Phản hồi rung haptic mạnh
    try {
      await HapticFeedback.vibrate();
      await HapticFeedback.heavyImpact();
    } catch (_) {}

    // 2. Gọi Native Audio (Kích hoạt Vibrator phần cứng + AudioTrack Nốt Đô)
    try {
      await _nativeAudioChannel.invokeMethod<bool>('playConfirmBeep');
    } catch (e) {
      developer.log('Native confirm beep error: $e', name: 'SoundService');
    }

    // 3. Dự phòng song song SystemSound
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}

    // 4. Dự phòng AudioPlayer với file confirm_success.wav (Nốt Đô)
    try {
      await init();
      await _player.stop();
      await _player.play(AssetSource('audio/confirm_success.wav'), volume: 1.0);
    } catch (e) {
      developer.log('AudioPlayer error: $e', name: 'SoundService');
    }
  }

  /// Tương thích ngược: mặc định phát tiếng scan beep
  Future<void> playSuccessBeep() => playScanSuccessBeep();

  /// Rung haptic phần cứng (dùng khi thẻ chưa đăng ký hoặc nhận thẻ)
  Future<void> vibrateOnly() async {
    try {
      await HapticFeedback.vibrate();
    } catch (_) {}
    try {
      await _nativeAudioChannel.invokeMethod<bool>('vibrate');
    } catch (_) {}
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
