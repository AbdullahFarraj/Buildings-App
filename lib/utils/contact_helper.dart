import 'package:url_launcher/url_launcher.dart';

class ContactHelper {
  static const String supportPhone = '971522807077';
  static const String supportPhoneDisplay = '+971 52 280 7077';
  static const String supportEmail = 'info@elitelivingre.com';

  static Future<void> launchWhatsApp(String phone, {String text = ''}) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanPhone.startsWith('00')) {
      cleanPhone = cleanPhone.substring(2);
    }
    if (cleanPhone.startsWith('05') && cleanPhone.length == 10) {
      cleanPhone = '971${cleanPhone.substring(1)}';
    } else if (cleanPhone.startsWith('5') && cleanPhone.length == 9) {
      cleanPhone = '971$cleanPhone';
    }
    
    final uriString = text.isNotEmpty
        ? 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(text)}'
        : 'https://wa.me/$cleanPhone';
    final url = Uri.parse(uriString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> launchCall(String phone) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.startsWith('00')) {
      cleanPhone = '+${cleanPhone.substring(2)}';
    } else if (!cleanPhone.startsWith('+')) {
      cleanPhone = '+$cleanPhone';
    }
    final url = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  static String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  static Future<void> launchEmail(String email, {String subject = '', String body = ''}) async {
    // Normalize newlines to \r\n for universal compatibility across email clients (Outlook, Mail, etc.)
    final normalizedBody = body.replaceAll('\r\n', '\n').replaceAll('\n', '\r\n');

    final Map<String, String> queryParams = {
      if (subject.isNotEmpty) 'subject': subject,
      if (normalizedBody.isNotEmpty) 'body': normalizedBody,
    };

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
      query: queryParams.isNotEmpty ? _encodeQueryParameters(queryParams) : null,
    );
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
    }
  }
}
