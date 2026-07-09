String formatPropertyAddress(Map<String, dynamic>? prop) {
  if (prop == null) return 'Unknown Property';
  final parts = <String>[];
  if (prop['room_no'] != null && prop['room_no'].toString().trim().isNotEmpty) {
    parts.add(prop['room_no'].toString().trim());
  }
  if (prop['address_line_1'] != null && prop['address_line_1'].toString().trim().isNotEmpty) {
    parts.add(prop['address_line_1'].toString().trim());
  }
  if (prop['city'] != null && prop['city'].toString().trim().isNotEmpty) {
    parts.add(prop['city'].toString().trim());
  }
  if (prop['postcode'] != null && prop['postcode'].toString().trim().isNotEmpty) {
    parts.add(prop['postcode'].toString().trim());
  }
  return parts.isEmpty ? 'Unknown Property' : parts.join(', ');
}
