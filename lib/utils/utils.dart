import 'package:flutter/material.dart';

Color getTextColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.light
      ? Colors.black
      : Colors.white;
}
