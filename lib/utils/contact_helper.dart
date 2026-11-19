import 'package:url_launcher/url_launcher.dart';
import 'phone_helper.dart';

class ContactHelper {
  static const String supportPhone = '971522807077';
  static const String supportPhoneDisplay = '+971 52 280 7077';
  static const String supportEmail = 'info@elitelivingre.com';

  static Future<bool> launchWhatsApp(String phone, {String text = ''}) async {
    String cleanPhone = PhoneHelper.normalizeUaeMobile(phone) ??
        phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanPhone.startsWith('00')) {
      cleanPhone = cleanPhone.substring(2);
    }
    if (cleanPhone.isEmpty) return false;

    final uriString = text.isNotEmpty
        ? 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(text)}'
        : 'https://wa.me/$cleanPhone';
    final url = Uri.tryParse(uriString);
    if (url == null) return false;

    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> launchCall(String phone) async {
    final dialNumber = PhoneHelper.formatForDial(phone);
    if (dialNumber.isEmpty) return false;

    final url = Uri(scheme: 'tel', path: dialNumber);
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static String _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  static Future<bool> launchEmail(String email, {String subject = '', String body = ''}) async {
    if (email.trim().isEmpty) return false;

    // Normalize newlines to \r\n for universal compatibility across email clients (Outlook, Mail, etc.)
    final normalizedBody = body.replaceAll('\r\n', '\n').replaceAll('\n', '\r\n');

    final Map<String, String> queryParams = {
      if (subject.isNotEmpty) 'subject': subject,
      if (normalizedBody.isNotEmpty) 'body': normalizedBody,
    };

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email.trim(),
      query: queryParams.isNotEmpty ? _encodeQueryParameters(queryParams) : null,
    );
    try {
      return await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
