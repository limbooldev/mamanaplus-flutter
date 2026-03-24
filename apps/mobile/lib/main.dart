import 'package:flutter/material.dart';
import 'package:mamana_plus_core/mamana_plus_core.dart';

void main() {
  runApp(const MamanaPlusApp());
}

class MamanaPlusApp extends StatelessWidget {
  const MamanaPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MamanaPlus',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const _HomePlaceholder(),
    );
  }
}

/// Temporary shell until chat UI is wired. Verifies `mamana_plus_core` resolves.
class _HomePlaceholder extends StatelessWidget {
  const _HomePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MamanaPlus')),
      body: Center(
        child: Text('Workspace OK: ${Awesome().isAwesome}'),
      ),
    );
  }
}
