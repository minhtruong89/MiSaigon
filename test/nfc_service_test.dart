import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:micharity/controllers/app_controller.dart';
import 'package:micharity/models/app_mode.dart';
import 'package:micharity/services/nfc_service.dart';
import 'package:micharity/services/sound_service.dart';
import 'package:nfc_manager/nfc_manager.dart';

class MockSoundService extends SoundService {
  int beepCount = 0;

  @override
  Future<void> init() async {}

  @override
  Future<void> playSuccessBeep() async {
    beepCount++;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NfcCardInfo and Tag Parsing Tests', () {
    test('parseTag trích xuất đúng UID dạng Hex và công nghệ NfcA', () {
      final mockTag = NfcTag(
        handle: 'mock_handle_1',
        data: {
          'nfca': {
            'identifier': Uint8List.fromList([0x04, 0xA2, 0xB3, 0xC4]),
            'atqa': Uint8List.fromList([0x00, 0x04]),
            'sak': 0x08,
          },
        },
      );

      final cardInfo = NfcService.parseTag(mockTag);
      expect(cardInfo, isNotNull);
      expect(cardInfo!.uidHex, equals('04:A2:B3:C4'));
      expect(cardInfo.uidRawHex, equals('04A2B3C4'));
      expect(cardInfo.technologies, contains('NfcA'));
    });

    test('parseTag trích xuất đúng UID từ MifareClassic', () {
      final mockTag = NfcTag(
        handle: 'mock_handle_2',
        data: {
          'mifareclassic': {
            'identifier': Uint8List.fromList([0x12, 0x34, 0x56, 0x78]),
            'type': 0,
            'size': 1024,
            'sectorCount': 16,
            'blockCount': 64,
          },
        },
      );

      final cardInfo = NfcService.parseTag(mockTag);
      expect(cardInfo, isNotNull);
      expect(cardInfo!.uidHex, equals('12:34:56:78'));
      expect(cardInfo.uidRawHex, equals('12345678'));
      expect(cardInfo.technologies, contains('MifareClassic'));
    });

    test('parseTag trích xuất fallback từ tag.data raw map', () {
      final mockTag = NfcTag(
        handle: 'mock_handle_3',
        data: {
          'custom_rfid': {
            'identifier': [0xDE, 0xAD, 0xBE, 0xEF],
          },
        },
      );

      final cardInfo = NfcService.parseTag(mockTag);
      expect(cardInfo, isNotNull);
      expect(cardInfo!.uidHex, equals('DE:AD:BE:EF'));
      expect(cardInfo.uidRawHex, equals('DEADBEEF'));
      expect(cardInfo.technologies, contains('custom_rfid'));
    });

    test('parseTag trả về null nếu không có identifier', () {
      final mockTag = NfcTag(
        handle: 'mock_handle_empty',
        data: {
          'empty_tech': {},
        },
      );

      final cardInfo = NfcService.parseTag(mockTag);
      expect(cardInfo, isNull);
    });
  });

  group('AppController NFC Card Detection Workflow', () {
    late MockSoundService mockSoundService;
    late AppController controller;

    setUp(() {
      mockSoundService = MockSoundService();
      controller = AppController(soundService: mockSoundService);
    });

    tearDown(() {
      controller.dispose();
    });

    test('Quét thẻ NFC phát tiếng bíp và GIỮ NGUYÊN trạng thái STANDBY (không chuyển WORKING)', () async {
      controller.setReady();
      expect(controller.mode, equals(AppMode.standby));

      final cardInfo = NfcCardInfo(
        uidHex: '04:A2:B3:C4',
        uidRawHex: '04A2B3C4',
        technologies: ['NfcA', 'MifareClassic'],
        rawData: {'test': 123},
      );

      await controller.onNfcCardDetected(cardInfo);

      // 1. Phải phát tiếng BÍP
      expect(mockSoundService.beepCount, equals(1));

      // 2. Không được chuyển sang working screen
      expect(controller.mode, equals(AppMode.standby));
      expect(controller.currentUrl, isNull);
      expect(controller.isProcessingQr, isFalse);

      // Quét thẻ tiếp theo vẫn kêu bíp và giữ nguyên standby
      final cardInfo2 = NfcCardInfo(
        uidHex: '11:22:33:44',
        uidRawHex: '11223344',
        technologies: ['IsoDep'],
        rawData: {},
      );

      await controller.onNfcCardDetected(cardInfo2);
      expect(mockSoundService.beepCount, equals(2));
      expect(controller.mode, equals(AppMode.standby));
    });
  });
}
