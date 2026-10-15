import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

void showScreenInfoDialog(
  BuildContext context, {
  required String title,
  required String description,
}) {
  showDialog(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: Text(title),
          content: Text(description),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.l10n.understood),
            ),
          ],
        ),
  );
}
