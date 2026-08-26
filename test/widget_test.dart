import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OTYA authentication contracts', () {
    final otpPattern = RegExp(r'^[A-Z][0-9]{4}$');

    test('accepts the required A1234 OTP format', () {
      expect(otpPattern.hasMatch('A1234'), isTrue);
      expect(otpPattern.hasMatch('Z0000'), isTrue);
    });

    test('rejects invalid OTP formats', () {
      expect(otpPattern.hasMatch('12345'), isFalse);
      expect(otpPattern.hasMatch('a1234'), isFalse);
      expect(otpPattern.hasMatch('AB123'), isFalse);
      expect(otpPattern.hasMatch('A123'), isFalse);
      expect(otpPattern.hasMatch('A12345'), isFalse);
      expect(otpPattern.hasMatch('A12B4'), isFalse);
    });
  });
}
