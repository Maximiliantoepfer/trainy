import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/exercise.dart';
import '../utils/duration_utils.dart';

Future<String?> showTextPromptDialog({
  required BuildContext context,
  required String title,
  required String label,
  required String submitLabel,
  required String cancelLabel,
  required String requiredMessage,
  String initialValue = '',
}) {
  return showDialog<String>(
    context: context,
    builder:
        (_) => TextPromptDialog(
          title: title,
          label: label,
          submitLabel: submitLabel,
          cancelLabel: cancelLabel,
          requiredMessage: requiredMessage,
          initialValue: initialValue,
        ),
  );
}

class TextPromptDialog extends StatefulWidget {
  const TextPromptDialog({
    super.key,
    required this.title,
    required this.label,
    required this.submitLabel,
    required this.cancelLabel,
    required this.requiredMessage,
    this.initialValue = '',
  });

  final String title;
  final String label;
  final String submitLabel;
  final String cancelLabel;
  final String requiredMessage;
  final String initialValue;

  @override
  State<TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<TextPromptDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: const ValueKey('textPromptField'),
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: widget.label),
          onFieldSubmitted: (_) => _submit(),
          validator:
              (value) =>
                  (value?.trim().isEmpty ?? true)
                      ? widget.requiredMessage
                      : null,
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('textPromptCancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          key: const ValueKey('textPromptSubmit'),
          onPressed: _submit,
          child: Text(widget.submitLabel),
        ),
      ],
    );
  }
}

Future<int?> showDurationInputDialog({
  required BuildContext context,
  required String title,
  required int initialSeconds,
}) {
  return showDialog<int>(
    context: context,
    builder:
        (_) =>
            DurationInputDialog(title: title, initialSeconds: initialSeconds),
  );
}

class DurationInputDialog extends StatefulWidget {
  const DurationInputDialog({
    super.key,
    required this.title,
    required this.initialSeconds,
  });

  final String title;
  final int initialSeconds;

  @override
  State<DurationInputDialog> createState() => _DurationInputDialogState();
}

class _DurationInputDialogState extends State<DurationInputDialog> {
  late final TextEditingController _hoursController;
  late final TextEditingController _minutesController;
  late final TextEditingController _secondsController;

  @override
  void initState() {
    super.initState();
    final duration = Duration(seconds: widget.initialSeconds);
    _hoursController = TextEditingController(text: '${duration.inHours}');
    _minutesController = TextEditingController(
      text: '${duration.inMinutes.remainder(60)}',
    );
    _secondsController = TextEditingController(
      text: '${duration.inSeconds.remainder(60)}',
    );
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  void _submit() {
    final hours = int.tryParse(_hoursController.text) ?? 0;
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    final seconds = int.tryParse(_secondsController.text) ?? 0;
    Navigator.of(context).pop(hours * 3600 + minutes * 60 + seconds);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('durationHours'),
              controller: _hoursController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: l10n.hours),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: const ValueKey('durationMinutes'),
              controller: _minutesController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: l10n.minutes),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: const ValueKey('durationSeconds'),
              controller: _secondsController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: l10n.seconds),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('durationSubmit'),
          onPressed: _submit,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

Future<num?> showNumberInputDialog({
  required BuildContext context,
  required String title,
  required String label,
  required num initialValue,
  required bool integer,
}) {
  return showDialog<num>(
    context: context,
    builder:
        (_) => NumberInputDialog(
          title: title,
          label: label,
          initialValue: initialValue,
          integer: integer,
        ),
  );
}

class NumberInputDialog extends StatefulWidget {
  const NumberInputDialog({
    super.key,
    required this.title,
    required this.label,
    required this.initialValue,
    required this.integer,
  });

  final String title;
  final String label;
  final num initialValue;
  final bool integer;

  @override
  State<NumberInputDialog> createState() => _NumberInputDialogState();
}

class _NumberInputDialogState extends State<NumberInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initialValue}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value =
        widget.integer
            ? int.tryParse(_controller.text.trim())
            : double.tryParse(_controller.text.trim().replaceAll(',', '.'));
    if (value != null) Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('numberInputField'),
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.numberWithOptions(decimal: !widget.integer),
        inputFormatters: [
          if (widget.integer) FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('numberInputSubmit'),
          onPressed: _submit,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

Future<Map<String, String>?> showExerciseValueDialog({
  required BuildContext context,
  required Exercise exercise,
  required String title,
  Map<String, String> initialValues = const {},
}) {
  return showDialog<Map<String, String>>(
    context: context,
    builder:
        (_) => ExerciseValueDialog(
          exercise: exercise,
          title: title,
          initialValues: initialValues,
        ),
  );
}

class ExerciseValueDialog extends StatefulWidget {
  const ExerciseValueDialog({
    super.key,
    required this.exercise,
    required this.title,
    this.initialValues = const {},
  });

  final Exercise exercise;
  final String title;
  final Map<String, String> initialValues;

  @override
  State<ExerciseValueDialog> createState() => _ExerciseValueDialogState();
}

class _ExerciseValueDialogState extends State<ExerciseValueDialog> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    if (widget.exercise.trackReps) {
      _controllers['reps'] = TextEditingController(
        text: widget.initialValues['reps'] ?? '',
      );
    }
    if (widget.exercise.trackWeight) {
      _controllers['weight'] = TextEditingController(
        text: widget.initialValues['weight'] ?? '',
      );
    }
    if (widget.exercise.trackDuration) {
      final duration = DurationFormatter.fromRaw(
        widget.initialValues['duration'],
      );
      _controllers['durationHours'] = TextEditingController(
        text: duration.hours > 0 ? '${duration.hours}' : '',
      );
      _controllers['durationMinutes'] = TextEditingController(
        text: duration.minutes > 0 ? '${duration.minutes}' : '',
      );
      _controllers['durationSeconds'] = TextEditingController(
        text: duration.seconds > 0 ? '${duration.seconds}' : '',
      );
    }
    if (widget.exercise.trackDistance) {
      _controllers['distance'] = TextEditingController(
        text: widget.initialValues['distance'] ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final values = <String, String>{};
    for (final key in const ['reps', 'weight', 'distance']) {
      final text = _controllers[key]?.text.trim() ?? '';
      if (text.isNotEmpty) values[key] = text;
    }
    if (widget.exercise.trackDuration) {
      final seconds = DurationFormatter.totalSecondsFromTexts(
        _controllers['durationHours']?.text,
        _controllers['durationMinutes']?.text,
        _controllers['durationSeconds']?.text,
      );
      if (seconds > 0) values['duration'] = '$seconds';
    }
    Navigator.of(context).pop(values);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fields = <Widget>[];
    void addField(
      String key,
      String label, {
      bool decimal = false,
      String? hint,
    }) {
      final controller = _controllers[key];
      if (controller == null) return;
      fields.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            key: ValueKey('exerciseValue_$key'),
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: decimal),
            decoration: InputDecoration(labelText: label, hintText: hint),
          ),
        ),
      );
    }

    addField('reps', l10n.repetitions);
    addField('weight', l10n.weightKilograms, decimal: true);
    addField('distance', l10n.distanceKilometers, decimal: true);
    if (widget.exercise.trackDuration) {
      fields.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.duration,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final entry in [
                    ('durationHours', l10n.hours),
                    ('durationMinutes', l10n.minutes),
                    ('durationSeconds', l10n.seconds),
                  ]) ...[
                    Expanded(
                      child: TextField(
                        key: ValueKey('exerciseValue_${entry.$1}'),
                        controller: _controllers[entry.$1],
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(labelText: entry.$2),
                      ),
                    ),
                    if (entry.$1 != 'durationSeconds') const SizedBox(width: 8),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
    }

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: fields),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('exerciseValueSubmit'),
          onPressed: _submit,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
