import 'package:flutter/material.dart';
import '../l10n/strength_l10n.dart';

Future<String?> pickStrengthRoutine(
  BuildContext context, {
  required bool cooling,
}) => showModalBottomSheet<String>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder:
      (c) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  c.strength(cooling ? 'cooldown' : 'warmup'),
                  style: Theme.of(c).textTheme.titleLarge,
                ),
              ),
              for (final key in ['upper', 'lower', 'fullBody'])
                ListTile(
                  leading: const Icon(Icons.self_improvement),
                  title: Text(c.strength(key)),
                  subtitle: Text(c.strength('standardRoutine')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(c, key),
                ),
              ListTile(
                leading: const Icon(Icons.tune),
                title: Text(c.strength('individualRoutine')),
                onTap: () => Navigator.pop(c, 'individual'),
              ),
              ListTile(
                leading: const Icon(Icons.remove_circle_outline),
                title: Text(c.strength('noRoutine')),
                onTap: () => Navigator.pop(c, 'none'),
              ),
            ],
          ),
        ),
      ),
);
