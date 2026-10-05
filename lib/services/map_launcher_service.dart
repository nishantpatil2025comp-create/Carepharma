import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Helper utility to open Google Maps turn-by-turn driving directions to a destination.
Future<bool> openGoogleMapsRoute(double lat, double lon) async {
  final Uri googleMapsUrl = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving',
  );

  try {
    if (await canLaunchUrl(googleMapsUrl)) {
      return await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      return await launchUrl(googleMapsUrl);
    }
  } catch (e) {
    debugPrint('[MapLauncher] Could not launch Google Maps navigation: $e');
    return false;
  }
}
