import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Keeps the caller's immutable draft and write identity alive across retries.
/// Persistence belongs to the supplied action, never to the form widget.
Future<T?> showLocalSave<T>(
  BuildContext context,
  Future<T> Function() action,
) => showDialog<T>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _LocalSaveDialog<T>(action: action),
);

class _LocalSaveDialog<T> extends StatefulWidget {
  const _LocalSaveDialog({required this.action});
  final Future<T> Function() action;
  @override
  State<_LocalSaveDialog<T>> createState() => _LocalSaveDialogState<T>();
}

class _LocalSaveDialogState<T> extends State<_LocalSaveDialog<T>> {
  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    // Actions may synchronously notify a provider before their first await.
    // Do not start a write while this route is still being mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _save();
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final value = await widget.action();
      if (mounted) Navigator.of(context).pop(value);
    } catch (error, stack) {
      debugPrint('Local save failed: $error');
      debugPrintStack(stackTrace: stack, maxFrames: 12);
      if (mounted) {
        setState(() {
          _error = error;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(context.l10n.save),
      content:
          _error == null
              ? const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator()),
              )
              : Text(context.l10n.localSaveFailed),
      actions: [
        if (!_saving) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(onPressed: _save, child: Text(context.l10n.retry)),
        ],
      ],
    ),
  );
}
