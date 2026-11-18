/// Money is stored as integer paise everywhere to avoid floating point drift.
String formatPaise(int paise) {
  final rupees = paise ~/ 100;
  final rest = paise % 100;
  final whole = _groupIndian(rupees);
  return rest == 0 ? '₹$whole' : '₹$whole.${rest.toString().padLeft(2, '0')}';
}

/// 1234567 -> 12,34,567 (Indian digit grouping).
String _groupIndian(int value) {
  final digits = value.toString();
  if (digits.length <= 3) return digits;
  final last3 = digits.substring(digits.length - 3);
  var head = digits.substring(0, digits.length - 3);
  final parts = <String>[];
  while (head.length > 2) {
    parts.insert(0, head.substring(head.length - 2));
    head = head.substring(0, head.length - 2);
  }
  if (head.isNotEmpty) parts.insert(0, head);
  return '${parts.join(',')},$last3';
}

/// 8:05 PM
String formatTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// 19 Nov 2026
String formatDate(DateTime d) =>
    '${d.day} ${_monthNames[d.month - 1]} ${d.year}';

/// 19 Nov 2026, 8:05 PM
String formatOrderDate(DateTime d) => '${formatDate(d)}, ${formatTime(d)}';

abstract final class Validators {
  static final _phone = RegExp(r'^[6-9]\d{9}$');
  static final _pincode = RegExp(r'^[1-9]\d{5}$');

  static String? phone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your mobile number';
    if (!_phone.hasMatch(v)) return 'Enter a valid 10-digit mobile number';
    return null;
  }

  static String? pincode(String? value) {
    final v = value?.trim() ?? '';
    if (!_pincode.hasMatch(v)) return 'Enter a valid 6-digit pincode';
    return null;
  }

  static String? Function(String?) required(String label) {
    return (value) => (value?.trim().isEmpty ?? true) ? 'Enter $label' : null;
  }
}
