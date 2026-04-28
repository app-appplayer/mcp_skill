/// Bundle loader for loading skill bundles from various sources.
library;

import 'dart:convert';
import 'skill_bundle.dart';

/// Abstract loader for skill bundles.
abstract class BundleLoader {
  /// Load a bundle from a JSON map.
  Future<SkillBundle> loadJson(Map<String, dynamic> json);

  /// Load a bundle from a JSON string.
  Future<SkillBundle> loadString(String content);
}

/// Default bundle loader implementation.
class DefaultBundleLoader extends BundleLoader {
  @override
  Future<SkillBundle> loadJson(Map<String, dynamic> json) async {
    return SkillBundle.fromJson(json);
  }

  @override
  Future<SkillBundle> loadString(String content) async {
    final json = jsonDecode(content) as Map<String, dynamic>;
    return loadJson(json);
  }
}
