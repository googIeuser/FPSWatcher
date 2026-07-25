import 'dart:async';
import 'package:flutter/material.dart';
import 'src/app.dart';
import 'src/state/app_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController();
  runApp(FpsWatcherApp(controller: controller));
  unawaited(controller.initialize());
}
