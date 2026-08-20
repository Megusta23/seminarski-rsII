import 'package:flutter/material.dart';
import 'package:ladder_social_core/ladder_social_core.dart';

final class ScaffoldReadyScreen extends StatelessWidget {
  const ScaffoldReadyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ladder Social')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.check_circle_outline, size: 72),
                const SizedBox(height: 24),
                Text(
                  'Mobile scaffold is ready',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'The next vertical slice is authentication: register, login, '
                  'refresh token and the current profile.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SelectableText('API: ${AppConfig.apiBaseUrl}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
