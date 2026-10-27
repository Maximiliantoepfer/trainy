import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cardio_provider.dart';
import '../l10n/cardio_l10n.dart';
import '../themes/app_theme.dart';

class HealthConnectionStatus extends StatelessWidget {
  const HealthConnectionStatus({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<CardioProvider>(), service = p.health;
    final read = service.accessState?.readState;
    final key =
        service.syncState == 'failed'
            ? 'healthFailed'
            : !p.profile.healthEnabled
            ? 'healthConnect'
            : service.syncState == 'syncing'
            ? 'healthSync'
            : read == 'denied' ||
                read == 'unavailable' ||
                service.routeState == 'consentRequired'
            ? 'healthAction'
            : read == 'limited'
            ? 'healthPartial'
            : read == 'granted'
            ? 'healthActive'
            : 'healthConfigured';
    final good = ['healthActive', 'healthConfigured'].contains(key);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          good
              ? Icons.check_circle
              : key == 'healthSync'
              ? Icons.sync
              : Icons.info_outline,
          size: 20,
          color:
              good
                  ? AppTheme.success(context)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Flexible(child: Text(context.recording(key))),
      ],
    );
  }
}
