import 'package:flutter/material.dart';

import '../../core/widgets/app_empty_state.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AppEmptyState(
        title: title,
        icon: Icons.construction_outlined,
        message: 'Layar ini dibangun pada Phase 2–4.',
      ),
    );
  }
}
