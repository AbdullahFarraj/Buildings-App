class PhoneHelper {
  /// Normalizes a UAE mobile number to 12-digit `9715xxxxxxxx` format,
  /// or returns `null` if the input is not a valid UAE mobile number.
  static String? normalizeUaeMobile(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;

    String normalized = digits;
    if (digits.startsWith('009715') && digits.length == 14) {
      normalized = digits.substring(2);
    } else if (digits.startsWith('97105') && digits.length == 13) {
      normalized = '9715${digits.substring(5)}';
    } else if (digits.startsWith('05') && digits.length == 10) {
      normalized = '971${digits.substring(1)}';
    } else if (digits.startsWith('5') && digits.length == 9) {
      normalized = '971$digits';
    }

    if (normalized.length == 12 && normalized.startsWith('9715')) {
      return normalized;
    }
    return null;
  }

  /// Converts a UAE mobile number safely to local `05xxxxxxxx` format,
  /// returning `null` if invalid (never throws RangeError).
  static String? toLocalUaeFormat(String raw) {
    final normalized = normalizeUaeMobile(raw);
    if (normalized == null) return null;
    return '05${normalized.substring(4)}';
  }

  /// Returns phone_index lookup variants (`9715...`, `05...`, `+9715...`) for valid UAE numbers,
  /// or `{cleaned}` for non-UAE numbers so stale cleanup never crashes.
  static Set<String> getUaeVariants(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[\s\-()]'), '');
    if (cleaned.isEmpty) return {};

    final normalized = normalizeUaeMobile(cleaned);
    if (normalized != null) {
      final local = '05${normalized.substring(4)}';
      return {normalized, local, '+$normalized'};
    }
    return {cleaned};
  }

  /// Formats a phone number into an international E.164-like dial string (`+9715...`).
  static String formatForDial(String phone) {
    final uae = normalizeUaeMobile(phone);
    if (uae != null) {
      return '+$uae';
    }

    String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return '';
    if (cleanPhone.startsWith('00')) {
      return '+${cleanPhone.substring(2)}';
    }
    if (!cleanPhone.startsWith('+')) {
      return '+$cleanPhone';
    }
    return cleanPhone;
  }

  /// Returns `true` only if [rawUrl] is a valid HTTPS URL with a non-empty host.
  static bool isSafeHttpsUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return false;
    final uri = Uri.tryParse(rawUrl.trim());
    return uri != null && uri.scheme.toLowerCase() == 'https' && uri.host.isNotEmpty;
  }

  /// Returns `true` only if [rawUrl] is a valid Firebase Storage HTTPS URL.
  static bool isSafeFirebaseStorageUrl(String? rawUrl) {
    if (!isSafeHttpsUrl(rawUrl)) return false;
    final host = Uri.parse(rawUrl!.trim()).host.toLowerCase();
    return host == 'firebasestorage.googleapis.com' ||
        host == 'storage.googleapis.com';
  }
}
