import 'package:url_launcher/url_launcher.dart';

class ContactHelper {
  static Future<void> launchWhatsApp(String phone) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Add country code if missing (Assuming Jordan +962 or similar based on region)
    // For now, if the user didn't enter +, we can just launch what they have.
    // However, WhatsApp requires country code without +.
    if (cleanPhone.startsWith('+')) {
      cleanPhone = cleanPhone.substring(1);
    }
    
    final url = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      // Could not launch WhatsApp
    }
  }

  static Future<void> launchCall(String phone) async {
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
}
