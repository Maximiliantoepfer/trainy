import 'package:flutter/material.dart';
import '../services/settings_database.dart';
import '../screens/welcome_setup_screen.dart';
import '../l10n/plan_l10n.dart';

/// Presentation gate only. Completion is written by the successful setup flow.
class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key, required this.child});
  final Widget child;
  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool _checked = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    if (_checked || !mounted) return;
    _checked = true;
    try {
      final done = await SettingsDatabase.instance.getOnboardingDone();
      if (!done && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeSetupScreen()),
        );
      }
    } catch (_) {
      _checked = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.plan('error')),
            action: SnackBarAction(
              label: context.plan('retry'),
              onPressed: _check,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
