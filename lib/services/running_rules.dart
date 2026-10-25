import 'dart:convert';
import 'generated/running_rules.g.dart';

class RunningRules {
  RunningRules.fromJson(this.json) {
    if (version < 4 || json['rules'] is! Map || json['templates'] is! Map) {
      throw const FormatException('Invalid running rules');
    }
    for (final raw in (json['rules'] as Map).values) {
      final rule = raw as Map;
      if (rule['value'] is! num ||
          !(rule['value'] as num).isFinite ||
          (rule['value'] as num) < 0 ||
          rule['reason'] is! String ||
          !['product', 'evidence'].contains(rule['kind'])) {
        throw const FormatException('Invalid rule metadata');
      }
    }
    if (number('minimumEasyRuns') < 3 ||
        number('maximumSpeedIncrease') > .05 ||
        number('minimumGpsCoverage') > 1 ||
        number('maximumEasyRuns') < number('minimumEasyRuns')) {
      throw const FormatException('Unsafe or inconsistent rule configuration');
    }
  }
  final Map<String, dynamic> json;
  static final bundled = RunningRules.fromJson(
    jsonDecode(runningRulesJson) as Map<String, dynamic>,
  );
  int get version => json['version'] as int;
  double number(String key) =>
      ((json['rules'] as Map)[key]['value'] as num).toDouble();
  int integer(String key) => number(key).toInt();
  Map<String, dynamic> distance(double meters) => Map<String, dynamic>.from(
    (json['distances'] as Map)[meters == meters.roundToDouble()
            ? meters.toInt().toString()
            : '$meters']
        as Map,
  );
  List<String> rotation(bool beginner) => List<String>.from(
    json['templates'][beginner ? 'beginner' : 'intermediate'] as List,
  );
  List<Map<String, dynamic>> get runWalk =>
      (json['templates']['runWalk'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
}
