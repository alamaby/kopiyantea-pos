import 'package:flutter/material.dart';

/// ENH-003 — shared factory for the "optimistic delete + undo" pattern.
/// Used by cart line removal and invitation cancellation so both share the
/// same label, duration, and visual style.
SnackBar buildUndoSnackBar({
  required String message,
  required VoidCallback onUndo,
  Duration duration = const Duration(seconds: 4),
}) {
  return SnackBar(
    content: Text(message),
    duration: duration,
    behavior: SnackBarBehavior.floating,
    action: SnackBarAction(label: 'BATAL', onPressed: onUndo),
  );
}
