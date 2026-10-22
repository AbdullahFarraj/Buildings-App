import 'package:url_launcher/url_launcher.dart';

class ContactHelper {
  static const String supportPhone = '971500000000';
  static const String supportEmail = 'info@elitelivingre.ae';

  static Future<void> launchWhatsApp(String phone, {String text = ''}) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
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
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final url = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  static Future<void> launchEmail(String email, {String subject = '', String body = ''}) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        if (subject.isNotEmpty) 'subject': subject,
        if (body.isNotEmpty) 'body': body,
      },
    );
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
    }
  }
}
