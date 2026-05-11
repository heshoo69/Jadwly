import 'package:flutter/material.dart';

class AppFeedbackService {
  AppFeedbackService._();

  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  static void showSnackBar(String message) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
