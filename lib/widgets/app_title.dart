import 'package:flutter/material.dart';

class AppTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String? emoji;

  const AppTitle(this.title, {this.icon, this.emoji, super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        if (emoji != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(emoji!, style: TextStyle(fontSize: 22)),
          ),
        if (icon != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(icon, size: 22, color: color),
          ),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
