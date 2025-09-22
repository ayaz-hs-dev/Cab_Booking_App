import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:taxi_app/features/driver/presentation/pages/driver_home.dart';
import 'package:taxi_app/features/passenger/presentation/pages/passenger_home.dart';
import 'package:taxi_app/services/notification/firebase_messsaging_service.dart';

class HomePage extends StatefulWidget {
  final String role;
  const HomePage({super.key, required this.role});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    _initialize();
    debugPrint("Role: ${widget.role}");
    debugPrint("[HomePage] initState called");
    super.initState();
  }

  Future<void> _initialize() async {
    final token = await FirebaseMessaging.instance.getToken();
    await FCMService.sendNotification(
      token!,
      "Hello!",
      "This is a Flutter-only test",
    );
    debugPrint("[HomePage] FCM Token: $token");
  }

  @override
  Widget build(BuildContext context) {
    if (widget.role == 'passenger') {
      return PassengerHome();
    } else {
      return DriverHome();
    }
  }
}
