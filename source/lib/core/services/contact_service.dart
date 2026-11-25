import 'package:url_launcher/url_launcher.dart';

/// Opens WhatsApp chats and the email app. Nothing is sent automatically:
/// the person always sees the message first and taps send themselves.
class ContactService {
  ContactService._();

  /// Digits only, with India's 91 added to 10-digit numbers.
  static String normalisePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '91$digits';
    if (digits.length == 11 && digits.startsWith('0')) {
      return '91${digits.substring(1)}';
    }
    return digits;
  }

  /// Opens a WhatsApp chat with the message typed in. With no phone number,
  /// WhatsApp lets the person pick the contact.
  static Future<bool> whatsApp(String phone, String message) {
    final n = normalisePhone(phone);
    final uri = Uri.parse(
        'https://wa.me/${n.isEmpty ? '' : n}?text=${Uri.encodeComponent(message)}');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> email(String to, String subject, String body) {
    final uri = Uri(
      scheme: 'mailto',
      path: to,
      query:
          'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    return launchUrl(uri);
  }
}
