import 'package:flutter_test/flutter_test.dart';
import 'package:micharity/services/qr_service.dart';

void main() {
  group('QR Code URL Validation Tests', () {
    test('Hợp lệ với domain dtri2206.github.io và scheme HTTPS', () {
      expect(QrService.isValidQrUrl('https://dtri2206.github.io/'), isTrue);
      expect(QrService.isValidQrUrl('https://dtri2206.github.io/test'), isTrue);
      expect(QrService.isValidQrUrl('https://dtri2206.github.io/member/123'), isTrue);
      expect(QrService.isValidQrUrl('https://dtri2206.github.io/test?id=123'), isTrue);
      expect(QrService.isValidQrUrl('https://dtri2206.github.io/a/b/c?id=123&name=test#section1'), isTrue);
      expect(QrService.isValidQrUrl('https://dtri2206.github.io'), isTrue);
    });

    test('Không hợp lệ khi scheme là HTTP hoặc scheme khác', () {
      expect(QrService.isValidQrUrl('http://dtri2206.github.io/test'), isFalse);
      expect(QrService.isValidQrUrl('javascript:alert(1)'), isFalse);
      expect(QrService.isValidQrUrl('file:///test'), isFalse);
      expect(QrService.isValidQrUrl('data:text/html,test'), isFalse);
      expect(QrService.isValidQrUrl('intent://test'), isFalse);
    });

    test('Không hợp lệ khi host khác dtri2206.github.io', () {
      expect(QrService.isValidQrUrl('https://google.com'), isFalse);
      expect(QrService.isValidQrUrl('https://example.com/?redirect=dtri2206.github.io'), isFalse);
      expect(QrService.isValidQrUrl('https://fake-dtri2206.github.io/'), isFalse);
      expect(QrService.isValidQrUrl('https://github.com/dtri2206'), isFalse);
    });

    test('Không hợp lệ với null, chuỗi rỗng hoặc format sai', () {
      expect(QrService.isValidQrUrl(null), isFalse);
      expect(QrService.isValidQrUrl(''), isFalse);
      expect(QrService.isValidQrUrl('   '), isFalse);
      expect(QrService.isValidQrUrl('not_a_valid_url'), isFalse);
    });

    test('getValidatedUri trả về Uri chính xác cho URL hợp lệ', () {
      final uri = QrService.getValidatedUri('https://dtri2206.github.io/member/123?auth=true');
      expect(uri, isNotNull);
      expect(uri!.scheme, equals('https'));
      expect(uri.host, equals('dtri2206.github.io'));
      expect(uri.path, equals('/member/123'));
      expect(uri.queryParameters['auth'], equals('true'));
    });
  });
}
