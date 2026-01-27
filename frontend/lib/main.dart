import 'package:flutter/material.dart';

import 'src/api/api_client.dart';
import 'src/screens/home_shell.dart';

void main() {
  const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
  runApp(GoGoHannahApp(apiBaseUrl: apiBaseUrl));
}

class GoGoHannahApp extends StatelessWidget {
  final String apiBaseUrl;

  const GoGoHannahApp({super.key, required this.apiBaseUrl});

  @override
  Widget build(BuildContext context) {
    final apiClient = createApiClient(apiBaseUrl);
    return MaterialApp(
      title: 'GoGoHannah',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6B4EFF)),
        useMaterial3: true,
      ),
      home: HomeShell(apiClient: apiClient),
    );
  }
}
