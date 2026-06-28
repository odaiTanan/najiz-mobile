abstract final class AddressLabelUtils {
  static const partSeparator = ' - ';

  /// Normalizes Google Arabic addresses so separators render on all devices.
  static String format(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;

    return trimmed
        .replaceAll('\u060c', partSeparator)
        .replaceAll(RegExp(r'\?\s+'), partSeparator)
        .replaceAll(RegExp(r'\s*\?\s*'), partSeparator)
        .replaceAll(RegExp(r'(\s*-\s*)+'), partSeparator)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String joinParts(Iterable<String> parts) {
    return format(
      parts
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .join(partSeparator),
    );
  }
}
