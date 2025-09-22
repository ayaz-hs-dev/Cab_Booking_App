import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';

class FCMService {
  // ----------------------------
  // Paste your Service Account JSON here (VALID JSON)
  // ----------------------------
  static const _serviceAccountJson = r'''
{
 }
''';

  // ----------------------------
  // Step 1: Generate Access Token

  // ----------------------------
  static Future<String> _getAccessToken() async {
    final accountCredentials = ServiceAccountCredentials.fromJson(
      _serviceAccountJson,
    );
    final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

    final client = await clientViaServiceAccount(accountCredentials, scopes);
    final accessToken = client.credentials.accessToken.data;
    client.close();
    return accessToken;
  }

  // ----------------------------
  // Step 2: Send Notification
  // ----------------------------
  static Future<void> sendNotification(
    String deviceToken,
    String title,
    String body,
  ) async {
    final accessToken = await _getAccessToken();
    const projectId = "flutter-firebase-basics-bb333";

    final url = Uri.parse(
      "https://fcm.googleapis.com/v1/projects/$projectId/messages:send",
    );

    final headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $accessToken",
    };

    final payload = {
      "message": {
        "token": deviceToken,
        "notification": {"title": title, "body": body},
      },
    };

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      debugPrint("✅ Notification sent successfully!");
    } else if (response.statusCode == 401) {
      debugPrint("❌ Unauthorized! Check your service account credentials.");
    } else {
      debugPrint(
        "❌ Failed to send notification: ${response.statusCode} ${response.body}",
      );
    }
  }
}
