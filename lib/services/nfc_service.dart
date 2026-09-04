import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';
import 'package:permission_handler/permission_handler.dart';

/// Trạng thái hỗ trợ và kích hoạt NFC trên thiết bị
enum NfcSupportStatus {
  /// Thiết bị hỗ trợ NFC và NFC đang BẬT
  enabled,

  /// Thiết bị có phần cứng NFC nhưng đang TẮT trong Cài đặt
  disabled,

  /// Thiết bị không có phần cứng hỗ trợ NFC
  notSupported,
}

/// Thông tin trích xuất từ thẻ RFID/NFC khi quét thành công
class NfcCardInfo {
  /// UID thẻ dạng Hex phân tách bởi dấu hai chấm (vd: 04:A2:B3:C4)
  final String uidHex;

  /// UID thẻ dạng Hex liền nhau (vd: 04A2B3C4)
  final String uidRawHex;

  /// Danh sách các công nghệ chuẩn được phát hiện trên thẻ (NfcA, MifareClassic, Ndef, ...)
  final List<String> technologies;

  /// Dữ liệu NDEF text / payload nếu có
  final String? ndefPayload;

  /// Toàn bộ dữ liệu thô của thẻ nhận từ hệ thống
  final Map<String, dynamic> rawData;

  /// Thời điểm quét thẻ
  final DateTime timestamp;

  NfcCardInfo({
    required this.uidHex,
    required this.uidRawHex,
    required this.technologies,
    this.ndefPayload,
    required this.rawData,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Danh sách byte của UID trích xuất từ uidRawHex
  List<int> get uidBytes {
    final clean = uidRawHex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    final bytes = <int>[];
    for (int i = 0; i < clean.length - 1; i += 2) {
      final b = int.tryParse(clean.substring(i, i + 2), radix: 16);
      if (b != null) bytes.add(b);
    }
    return bytes;
  }

  /// UID dạng Decimal (Little Endian - chuẩn đọc thẻ RFID thông dụng nhất)
  /// Ví dụ: UID Hex 43:d8:16:0c -> Little Endian 0C16D843 -> Decimal 202823747
  String? get uidDec {
    final bytes = uidBytes;
    if (bytes.isEmpty) return null;
    try {
      BigInt val = BigInt.zero;
      for (int i = bytes.length - 1; i >= 0; i--) {
        val = (val << 8) | BigInt.from(bytes[i]);
      }
      return val.toString();
    } catch (_) {
      return null;
    }
  }

  /// UID dạng Decimal chuẩn 10 chữ số (pad thêm số 0 ở đầu nếu chưa đủ 10 số)
  /// Ví dụ: 202823747 -> 0202823747
  String? get uidDecPadded {
    final dec = uidDec;
    if (dec == null) return null;
    if (dec.length < 10) {
      return dec.padLeft(10, '0');
    }
    return dec;
  }

  /// UID dạng Decimal (Big Endian - dự phòng cho một số loại đầu đọc)
  String? get uidDecBigEndian {
    final bytes = uidBytes;
    if (bytes.isEmpty) return null;
    try {
      BigInt val = BigInt.zero;
      for (int i = 0; i < bytes.length; i++) {
        val = (val << 8) | BigInt.from(bytes[i]);
      }
      return val.toString();
    } catch (_) {
      return null;
    }
  }

  /// Tập hợp tất cả các mã định danh tương đương của thẻ (Hex và Dec)
  Set<String> get allMatchingKeys {
    final keys = <String>{};

    // 1. Hex
    final cleanHex = uidRawHex.trim().toLowerCase();
    if (cleanHex.isNotEmpty) {
      keys.add(cleanHex);
    }
    final formattedHex = uidHex.trim().toLowerCase();
    if (formattedHex.isNotEmpty) {
      keys.add(formattedHex);
      keys.add(formattedHex.replaceAll(':', ''));
    }

    // 2. Dec Little Endian (chuẩn RFID)
    final decLE = uidDec;
    if (decLE != null && decLE.isNotEmpty) {
      keys.add(decLE);
      final noLeadingZero = decLE.replaceFirst(RegExp(r'^0+'), '');
      if (noLeadingZero.isNotEmpty) keys.add(noLeadingZero);
      keys.add(decLE.padLeft(10, '0'));
    }

    // 3. Dec Big Endian
    final decBE = uidDecBigEndian;
    if (decBE != null && decBE.isNotEmpty) {
      keys.add(decBE);
      final noLeadingZeroBE = decBE.replaceFirst(RegExp(r'^0+'), '');
      if (noLeadingZeroBE.isNotEmpty) keys.add(noLeadingZeroBE);
      keys.add(decBE.padLeft(10, '0'));
    }

    // 4. Hỗ trợ thẻ 7 byte (Mifare Ultralight/NTAG)
    final bytes = uidBytes;
    if (bytes.length == 7) {
      try {
        BigInt valFirst4 = BigInt.zero;
        for (int i = 3; i >= 0; i--) {
          valFirst4 = (valFirst4 << 8) | BigInt.from(bytes[i]);
        }
        final s1 = valFirst4.toString();
        keys.add(s1);
        keys.add(s1.padLeft(10, '0'));
        final s1NoZero = s1.replaceFirst(RegExp(r'^0+'), '');
        if (s1NoZero.isNotEmpty) keys.add(s1NoZero);

        BigInt valLast4 = BigInt.zero;
        for (int i = 6; i >= 3; i--) {
          valLast4 = (valLast4 << 8) | BigInt.from(bytes[i]);
        }
        final s2 = valLast4.toString();
        keys.add(s2);
        keys.add(s2.padLeft(10, '0'));
        final s2NoZero = s2.replaceFirst(RegExp(r'^0+'), '');
        if (s2NoZero.isNotEmpty) keys.add(s2NoZero);
      } catch (_) {}
    }

    return keys;
  }

  @override
  String toString() {
    return 'NfcCardInfo(UID Hex: $uidHex, Dec: $uidDec / $uidDecPadded, Tech: $technologies, NDEF: $ndefPayload)';
  }
}

/// Dịch vụ quản lý quét ngầm thẻ RFID và NFC
class NfcService {
  static const MethodChannel _nfcChannel =
      MethodChannel('com.misaigon.micharity/nfc');

  final NfcManager _nfcManager;
  bool _isSessionActive = false;
  String? _lastScannedUid;
  DateTime? _lastScannedTime;

  /// Khoảng thời gian chống quét lặp liên tục cho cùng 1 thẻ (2.5 giây)
  static const Duration debounceDuration = Duration(milliseconds: 2500);

  NfcService({NfcManager? nfcManager})
      : _nfcManager = nfcManager ?? NfcManager.instance {
    _initNativeChannelListener();
  }

  ValueChanged<NfcCardInfo>? _activeCardCallback;

  void _initNativeChannelListener() {
    _nfcChannel.setMethodCallHandler((call) async {
      if (call.method == 'onNativeLog') {
        debugPrint('[Android NFC Log] ${call.arguments}');
      } else if (call.method == 'onCardDetected') {
        try {
          debugPrint('[NFC Service] Nhận tín hiệu onCardDetected từ Native Channel: ${call.arguments}');
          final data = Map<String, dynamic>.from(call.arguments as Map);
          final cardInfo = parseNativeTagData(data);
          if (cardInfo != null && _activeCardCallback != null) {
            _handleDiscoveredCardInfo(cardInfo, _activeCardCallback!);
          } else {
            debugPrint('[NFC Service] cardInfo: $cardInfo, _activeCardCallback: $_activeCardCallback');
          }
        } catch (e) {
          developer.log('Lỗi xử lý tag từ native channel: $e', name: 'NfcService');
          debugPrint('[NFC Service] Lỗi xử lý tag: $e');
        }
      }
    });
  }

  bool get isSessionActive => _isSessionActive;

  /// Kiểm tra thiết bị có hỗ trợ NFC và NFC đang bật hay tắt
  Future<NfcSupportStatus> checkSupportStatus() async {
    try {
      // 1. Kiểm tra phần cứng và trạng thái bật/tắt trên Android qua Native Channel
      if (Platform.isAndroid) {
        try {
          final isHardwarePresent =
              await _nfcChannel.invokeMethod<bool>('isNfcHardwarePresent');
          if (isHardwarePresent == false) {
            return NfcSupportStatus.notSupported;
          }

          final isEnabled =
              await _nfcChannel.invokeMethod<bool>('isNfcEnabled');
          if (isEnabled == true) {
            return NfcSupportStatus.enabled;
          } else {
            return NfcSupportStatus.disabled;
          }
        } catch (e) {
          developer.log('Lỗi kiểm tra phần cứng NFC qua native: $e',
              name: 'NfcService');
        }
      }

      // 2. Kiểm tra NfcManager isAvailable()
      final isAvailable = await _nfcManager.isAvailable();
      if (isAvailable) {
        return NfcSupportStatus.enabled;
      }

      if (Platform.isAndroid) {
        return NfcSupportStatus.disabled;
      }

      return NfcSupportStatus.notSupported;
    } catch (e) {
      developer.log('Lỗi kiểm tra trạng thái NFC: $e', name: 'NfcService');
      return NfcSupportStatus.notSupported;
    }
  }

  /// Mở màn hình cài đặt NFC của hệ thống (Android: ACTION_NFC_SETTINGS)
  Future<void> openNfcSettings() async {
    try {
      if (Platform.isAndroid) {
        await _nfcChannel.invokeMethod('openNfcSettings');
        return;
      }
      await openAppSettings();
    } catch (e) {
      developer.log('Lỗi mở Cài đặt NFC: $e', name: 'NfcService');
      try {
        await openAppSettings();
      } catch (_) {}
    }
  }

  /// Bắt đầu lắng nghe quét thẻ RFID/NFC chạy ngầm
  Future<void> startListening({
    required ValueChanged<NfcCardInfo> onCardDetected,
    ValueChanged<dynamic>? onError,
  }) async {
    if (_isSessionActive) {
      debugPrint('[NFC Service] Phiên quét đang hoạt động, bỏ qua gọi lặp.');
      return;
    }
    _activeCardCallback = onCardDetected;
    _isSessionActive = true;
    developer.log('Bắt đầu phiên quét ngầm RFID/NFC', name: 'NfcService');
    debugPrint('[NFC Service] Bắt đầu phiên quét ngầm RFID/NFC');

    // 1. Trên Android: Sử dụng Reader Mode của Native Channel tối ưu hóa cho RFID/NFC
    // KHÔNG gọi _nfcManager.startSession() trên Android vì plugin này ghi đè ReaderCallback
    // và gây ra NullPointerException hoặc bỏ rơi thẻ RFID không có chuẩn NDEF.
    if (Platform.isAndroid) {
      try {
        await _nfcChannel.invokeMethod('startScan');
        developer.log('Đã kích hoạt Native NFC Scanner trên Android',
            name: 'NfcService');
        debugPrint('[NFC Service] Đã kích hoạt Native NFC Scanner trên Android');
      } catch (e) {
        _isSessionActive = false;
        developer.log('Lỗi kích hoạt startScan native: $e', name: 'NfcService');
        debugPrint('[NFC Service] Lỗi kích hoạt startScan native: $e');
        onError?.call(e);
      }
      return;
    }

    // 2. Kích hoạt NfcManager startSession trên các nền tảng khác (iOS)
    try {
      final isAvailable = await _nfcManager.isAvailable();
      if (isAvailable) {
        await _nfcManager.startSession(
          invalidateAfterFirstRead: false,
          onDiscovered: (NfcTag tag) async {
            _handleDiscoveredTag(tag, onCardDetected);
          },
          onError: (NfcError error) async {
            developer.log('NfcManager session error: ${error.message}',
                name: 'NfcService');
            onError?.call(error);
          },
        );
      }
    } catch (e) {
      _isSessionActive = false;
      developer.log('NfcManager startSession exception: $e', name: 'NfcService');
      onError?.call(e);
    }
  }

  /// Dừng phiên lắng nghe NFC
  Future<void> stopListening() async {
    if (!_isSessionActive) return;
    _isSessionActive = false;
    _activeCardCallback = null;

    if (Platform.isAndroid) {
      try {
        await _nfcChannel.invokeMethod('stopScan');
        debugPrint('[NFC Service] Đã dừng Native NFC Reader Mode trên Android');
      } catch (e) {
        developer.log('Lỗi dừng stopScan native: $e', name: 'NfcService');
      }
      return;
    }

    try {
      await _nfcManager.stopSession();
    } catch (_) {}
    developer.log('Đã dừng phiên quét ngầm RFID/NFC', name: 'NfcService');
  }

  /// Xử lý dữ liệu thẻ khi phát hiện từ NfcTag
  void _handleDiscoveredTag(
      NfcTag tag, ValueChanged<NfcCardInfo> onCardDetected) {
    try {
      final cardInfo = parseTag(tag);
      if (cardInfo != null) {
        _handleDiscoveredCardInfo(cardInfo, onCardDetected);
      }
    } catch (e) {
      developer.log('Lỗi xử lý tag NFC: $e', name: 'NfcService');
    }
  }

  /// Xử lý dữ liệu thẻ và debounce
  void _handleDiscoveredCardInfo(
      NfcCardInfo cardInfo, ValueChanged<NfcCardInfo> onCardDetected) {
    final now = DateTime.now();
    if (_lastScannedUid == cardInfo.uidRawHex && _lastScannedTime != null) {
      if (now.difference(_lastScannedTime!) < debounceDuration) {
        return;
      }
    }

    _lastScannedUid = cardInfo.uidRawHex;
    _lastScannedTime = now;

    onCardDetected(cardInfo);
  }

  /// Phân tích dữ liệu thẻ nhận từ native Android channel
  static NfcCardInfo? parseNativeTagData(Map<String, dynamic> data) {
    final uidHex = data['uidHex'] as String?;
    final uidRawHex = data['uidRawHex'] as String?;
    if (uidHex == null || uidRawHex == null) return null;

    final techListRaw = data['technologies'] as List?;
    final techList = <String>[];
    if (techListRaw != null) {
      for (final t in techListRaw) {
        techList.add(standardizeTechName(t.toString()));
      }
    }

    return NfcCardInfo(
      uidHex: uidHex,
      uidRawHex: uidRawHex,
      technologies: techList.toSet().toList(),
      ndefPayload: data['ndefPayload'] as String?,
      rawData: data,
    );
  }

  /// Chuẩn hóa tên các công nghệ thẻ RFID/NFC
  static String standardizeTechName(String tech) {
    switch (tech.toLowerCase()) {
      case 'nfca':
        return 'NfcA';
      case 'nfcb':
        return 'NfcB';
      case 'nfcf':
        return 'NfcF';
      case 'nfcv':
        return 'NfcV';
      case 'isodep':
        return 'IsoDep';
      case 'mifareclassic':
        return 'MifareClassic';
      case 'mifareultralight':
        return 'MifareUltralight';
      case 'iso15693':
        return 'Iso15693';
      case 'felica':
        return 'FeliCa';
      case 'ndef':
        return 'Ndef';
      case 'ndefformatable':
        return 'NdefFormatable';
      default:
        return tech;
    }
  }

  /// Phân tích NfcTag thành đối tượng NfcCardInfo hoàn chỉnh
  static NfcCardInfo? parseTag(NfcTag tag) {
    Uint8List? identifier;
    final techList = <String>[];

    // 1. Trích xuất an toàn theo từng chuẩn thẻ RFID/NFC
    try {
      final nfcA = NfcA.from(tag);
      if (nfcA != null) {
        techList.add('NfcA');
        identifier ??= nfcA.identifier;
      }
    } catch (_) {}

    try {
      final mifareClassic = MifareClassic.from(tag);
      if (mifareClassic != null) {
        techList.add('MifareClassic');
        identifier ??= mifareClassic.identifier;
      }
    } catch (_) {}

    try {
      final mifareUltralight = MifareUltralight.from(tag);
      if (mifareUltralight != null) {
        techList.add('MifareUltralight');
        identifier ??= mifareUltralight.identifier;
      }
    } catch (_) {}

    try {
      final isoDep = IsoDep.from(tag);
      if (isoDep != null) {
        techList.add('IsoDep');
        identifier ??= isoDep.identifier;
      }
    } catch (_) {}

    try {
      final nfcB = NfcB.from(tag);
      if (nfcB != null) {
        techList.add('NfcB');
        identifier ??= nfcB.identifier;
      }
    } catch (_) {}

    try {
      final nfcF = NfcF.from(tag);
      if (nfcF != null) {
        techList.add('NfcF');
        identifier ??= nfcF.identifier;
      }
    } catch (_) {}

    try {
      final nfcV = NfcV.from(tag);
      if (nfcV != null) {
        techList.add('NfcV');
        identifier ??= nfcV.identifier;
      }
    } catch (_) {}

    try {
      final iso15693 = Iso15693.from(tag);
      if (iso15693 != null) {
        techList.add('Iso15693');
        identifier ??= iso15693.identifier;
      }
    } catch (_) {}

    try {
      final felica = FeliCa.from(tag);
      if (felica != null) {
        techList.add('FeliCa');
        identifier ??= felica.currentIDm;
      }
    } catch (_) {}

    try {
      final miFare = MiFare.from(tag);
      if (miFare != null) {
        techList.add('MiFare');
        identifier ??= miFare.identifier;
      }
    } catch (_) {}

    // 2. Quét trong tag.data để chuẩn hóa tên công nghệ và trích xuất UID
    for (final entry in tag.data.entries) {
      final key = entry.key;
      techList.add(standardizeTechName(key));
      final val = entry.value;
      if (val is Map) {
        final id = val['identifier'] ?? val['id'] ?? val['currentIDm'];
        if (id is Uint8List) {
          identifier ??= id;
        } else if (id is List) {
          identifier ??=
              Uint8List.fromList(List<int>.from(id));
        }
      }
    }

    // 3. Trích xuất dữ liệu NDEF nếu thẻ có ghi dữ liệu NDEF
    String? ndefPayload;
    try {
      final ndef = Ndef.from(tag);
      if (ndef != null) {
        techList.add('Ndef');
        final cachedMessage = ndef.cachedMessage;
        if (cachedMessage != null && cachedMessage.records.isNotEmpty) {
          final recordsInfo = <String>[];
          for (final record in cachedMessage.records) {
            try {
              final typeStr = String.fromCharCodes(record.type);
              final payloadStr = String.fromCharCodes(record.payload);
              recordsInfo.add('[$typeStr: $payloadStr]');
            } catch (_) {}
          }
          if (recordsInfo.isNotEmpty) {
            ndefPayload = recordsInfo.join(', ');
          }
        }
      }
    } catch (_) {}

    if (identifier == null || identifier.isEmpty) {
      return null;
    }

    final hexSeparated = identifier
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
    final hexRaw = identifier
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join('');

    return NfcCardInfo(
      uidHex: hexSeparated,
      uidRawHex: hexRaw,
      technologies: techList.toSet().toList(),
      ndefPayload: ndefPayload,
      rawData: Map<String, dynamic>.from(tag.data),
    );
  }
}
