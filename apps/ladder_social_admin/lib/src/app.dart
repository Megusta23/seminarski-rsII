import 'package:flutter/material.dart';
import 'package:ladder_social_admin/src/features/auth/presentation/admin_auth_gate.dart';

final class LadderSocialAdminApp extends StatelessWidget {
  const LadderSocialAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ladder Social Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const AdminAuthGate(),
    );
  }
}
