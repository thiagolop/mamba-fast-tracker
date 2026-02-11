import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/notifications/notifications_service.dart';
import 'core/storage/hive_boxes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await HiveBoxes.init();

  final auth = FirebaseAuth.instance;
  User? currentUser = auth.currentUser;
  currentUser ??= await auth.authStateChanges().first.timeout(
    const Duration(seconds: 5),
  );

  final container = ProviderContainer();
  await container.read(notificationsServiceProvider).init();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const App(),
    ),
  );
}
