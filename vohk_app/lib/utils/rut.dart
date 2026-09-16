import 'package:flutter/services.dart';

String normalizeRut(String value) {
  return value.replaceAll(RegExp(r'[^0-9kK]'), '').toUpperCase();
}

String formatRut(String value) {
  final normalized = normalizeRut(value);
  if (normalized.length < 2) return normalized;
  final body = normalized.substring(0, normalized.length - 1);
  final dv = normalized.substring(normalized.length - 1);
  final groups = <String>[];
  for (var end = body.length; end > 0; end -= 3) {
    final start = end - 3 < 0 ? 0 : end - 3;
    groups.add(body.substring(start, end));
  }
  return '${groups.reversed.join('.')}-$dv';
}

bool isValidRut(String value) {
  final normalized = normalizeRut(value);
  if (!RegExp(r'^\d{7,8}[0-9K]$').hasMatch(normalized)) return false;
  final body = normalized.substring(0, normalized.length - 1);
  final suppliedDv = normalized.substring(normalized.length - 1);
  var sum = 0;
  var multiplier = 2;
  for (var index = body.length - 1; index >= 0; index -= 1) {
    sum += int.parse(body[index]) * multiplier;
    multiplier = multiplier == 7 ? 2 : multiplier + 1;
  }
  final remainder = 11 - (sum % 11);
  final expectedDv = remainder == 11
      ? '0'
      : remainder == 10
      ? 'K'
      : remainder.toString();
  return suppliedDv == expectedDv;
}

class RutInputFormatter extends TextInputFormatter {
  const RutInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var normalized = normalizeRut(newValue.text);
    if (normalized.length > 9) normalized = normalized.substring(0, 9);
    final formatted = formatRut(normalized);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
