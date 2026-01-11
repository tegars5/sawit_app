import 'package:url_launcher/url_launcher.dart';

/// Helper class for launching external apps
class LauncherHelper {
  /// Make a phone call
  static Future<void> makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );

    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      throw Exception('Could not launch phone dialer');
    }
  }

  /// Send SMS
  static Future<void> sendSMS(String phoneNumber, {String? message}) async {
    final Uri launchUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: message != null ? {'body': message} : null,
    );

    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      throw Exception('Could not launch SMS app');
    }
  }

  /// Open URL in browser
  static Future<void> openUrl(String url) async {
    final Uri launchUri = Uri.parse(url);

    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch URL');
    }
  }

  /// Open email app
  static Future<void> sendEmail(String email,
      {String? subject, String? body}) async {
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        if (subject != null) 'subject': subject,
        if (body != null) 'body': body,
      },
    );

    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      throw Exception('Could not launch email app');
    }
  }

  /// Open Google Maps with coordinates
  static Future<void> openMaps(double latitude, double longitude) async {
    final Uri launchUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );

    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch maps');
    }
  }
}
