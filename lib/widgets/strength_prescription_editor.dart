import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../l10n/plan_l10n.dart';
import '../models/workout_planning.dart';

Future<StrengthPrescription?> editStrengthPrescription(
  BuildContext context,
  StrengthPrescription initial,
) async {
  final key = GlobalKey<FormState>();
  var sets = initial.sets, min = initial.minReps, max = initial.maxReps;
  return showDialog<StrengthPrescription>(
    context: context,
    builder:
        (c) => AlertDialog(
          title: Text(c.plan('edit')),
          content: Form(
            key: key,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final field in ['sets', 'min', 'max'])
                    TextFormField(
                      initialValue:
                          '${field == 'sets'
                              ? sets
                              : field == 'min'
                              ? min
                              : max}',
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText:
                            field == 'sets'
                                ? c.l10n.sets
                                : '${c.l10n.repetitions} · ${field == 'min' ? 'min' : 'max'}',
                      ),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        return n == null ||
                                n < 1 ||
                                n > (field == 'sets' ? 50 : 200) ||
                                (field == 'max' && n < min)
                            ? c.plan('positiveError')
                            : null;
                      },
                      onChanged: (v) {
                        final n = int.tryParse(v) ?? 0;
                        if (field == 'sets') {
                          sets = n;
                        } else if (field == 'min') {
                          min = n;
                        } else {
                          max = n;
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text(c.plan('cancel')),
            ),
            FilledButton(
              onPressed: () {
                if (key.currentState!.validate()) {
                  Navigator.pop(
                    c,
                    StrengthPrescription(
                      sets: sets,
                      minReps: min,
                      maxReps: max,
                    ),
                  );
                }
              },
              child: Text(c.plan('save')),
            ),
          ],
        ),
  );
}
