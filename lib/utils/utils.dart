import 'package:flutter/material.dart';

/// Nutze konsistent das ColorScheme statt fixer Farben.
Color textOnSurface(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface;
