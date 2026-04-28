/// Capability verifier for compile-time and runtime verification.
library;

import 'capability_types.dart';

/// Result of capability verification.
class VerificationResult {
  final bool satisfied;
  final List<String> missing;
  final List<String> warnings;

  const VerificationResult({
    required this.satisfied,
    this.missing = const [],
    this.warnings = const [],
  });

  factory VerificationResult.success() =>
      const VerificationResult(satisfied: true);

  factory VerificationResult.failure(List<String> missing) =>
      VerificationResult(satisfied: false, missing: missing);
}

/// Compile-time capability verification.
class CompileTimeVerifier {
  /// Verify that required capabilities can be satisfied.
  VerificationResult verify({
    required RequiredCapabilities required,
    required ProvidedCapabilities available,
  }) {
    final missing = <String>[];

    for (final portReq in required.ports) {
      if (portReq.required) {
        final hasPort = available.capabilities
            .any((c) => c.name == 'port:${portReq.type.name}');
        if (!hasPort) {
          missing.add('Required port: ${portReq.type.name}');
        }
      }
    }

    for (final skillId in required.skills) {
      final hasSkill =
          available.capabilities.any((c) => c.name == 'skill:$skillId');
      if (!hasSkill) {
        missing.add('Required skill: $skillId');
      }
    }

    if (missing.isEmpty) return VerificationResult.success();
    return VerificationResult.failure(missing);
  }
}

/// Runtime capability verification.
class RuntimeVerifier {
  /// Verify that runtime environment satisfies requirements.
  VerificationResult verify({
    required RequiredCapabilities required,
    required Set<PortType> availablePorts,
    required Set<String> availableSkills,
  }) {
    final missing = <String>[];

    for (final portReq in required.ports) {
      if (portReq.required && !availablePorts.contains(portReq.type)) {
        missing.add('Required port not available: ${portReq.type.name}');
      }
    }

    for (final skillId in required.skills) {
      if (!availableSkills.contains(skillId)) {
        missing.add('Required skill not available: $skillId');
      }
    }

    if (missing.isEmpty) return VerificationResult.success();
    return VerificationResult.failure(missing);
  }
}
