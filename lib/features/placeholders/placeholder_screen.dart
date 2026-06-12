import 'package:flutter/material.dart';

import '../../core/widgets/app_empty_state.dart';
import '../../l10n/generated/app_localizations.dart';

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
        message: AppL10n.of(context).placeholderScreenMessage,
      ),
    );
  }
}
