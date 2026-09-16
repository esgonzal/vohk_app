import 'package:flutter_test/flutter_test.dart';
import 'package:vohk_app/utils/rut.dart';

void main() {
  test('formats RUT with dots and dash', () {
    expect(formatRut('194893515'), '19.489.351-5');
    expect(formatRut('7.027.804-k'), '7.027.804-K');
  });

  test('validates the check digit regardless of punctuation', () {
    expect(isValidRut('19.489.351-5'), isTrue);
    expect(isValidRut('194893515'), isTrue);
    expect(isValidRut('19.489.351-4'), isFalse);
  });
}
