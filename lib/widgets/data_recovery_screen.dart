import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../providers/data_lifecycle_provider.dart';

class DataRecoveryScreen extends StatefulWidget {
  const DataRecoveryScreen({super.key});

  @override
  State<DataRecoveryScreen> createState() => _DataRecoveryScreenState();
}

class _DataRecoveryScreenState extends State<DataRecoveryScreen> {
  String? _message;

  Future<void> _export() async {
    try {
      final target =
          await context.read<DataLifecycleProvider>().exportRecoveryCopy();
      if (mounted)
        setState(() => _message = context.l10n.recoverySaved(target));
    } catch (_) {
      if (mounted) setState(() => _message = context.l10n.recoveryExportFailed);
    }
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(dialogContext.l10n.confirmResetAgain),
            content: Text(dialogContext.l10n.recoveryResetDescription),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(dialogContext.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(dialogContext.l10n.resetNow),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<DataLifecycleProvider>().resetLocalTrainingData();
  }

  @override
  Widget build(BuildContext context) {
    final lifecycle = context.watch<DataLifecycleProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.localDataRecovery)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                Icon(
                  Icons.health_and_safety_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  context.l10n.localDataNeedsRecovery,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.localDataNeedsRecoveryDescription,
                  textAlign: TextAlign.center,
                ),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Text(_message!, textAlign: TextAlign.center),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: lifecycle.isBusy ? null : lifecycle.retryStartup,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(context.l10n.retry),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: lifecycle.isBusy ? null : _export,
                  icon: const Icon(Icons.save_alt_rounded),
                  label: Text(context.l10n.saveRecoveryCopy),
                ),
                TextButton(
                  onPressed: lifecycle.isBusy ? null : _reset,
                  child: Text(context.l10n.resetLocalTrainingData),
                ),
                if (lifecycle.isBusy) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
