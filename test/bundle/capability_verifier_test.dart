import 'package:test/test.dart';
import 'package:mcp_skill/src/bundle/capability_verifier.dart';
import 'package:mcp_skill/src/bundle/capability_types.dart';

void main() {
  group('CompileTimeVerifier', () {
    late CompileTimeVerifier verifier;

    setUp(() {
      verifier = CompileTimeVerifier();
    });

    group('verify', () {
      test('returns success when all required ports are provided', () {
        final result = verifier.verify(
          required: const RequiredCapabilities(
            ports: [PortRequirement(type: PortType.llm, required: true)],
          ),
          available: const ProvidedCapabilities(
            capabilities: [SkillCapability(name: 'port:llm')],
          ),
        );

        expect(result.satisfied, isTrue);
        expect(result.missing, isEmpty);
      });

      test('fails when required port is not declared', () {
        final result = verifier.verify(
          required: const RequiredCapabilities(
            ports: [PortRequirement(type: PortType.llm, required: true)],
          ),
          available: const ProvidedCapabilities(capabilities: []),
        );

        expect(result.satisfied, isFalse);
        expect(result.missing, hasLength(1));
        expect(result.missing.first, contains('llm'));
      });

      test('ignores optional ports when not provided', () {
        final result = verifier.verify(
          required: const RequiredCapabilities(
            ports: [PortRequirement(type: PortType.knowledge, required: false)],
          ),
          available: const ProvidedCapabilities(capabilities: []),
        );

        expect(result.satisfied, isTrue);
        expect(result.missing, isEmpty);
      });

      test('checks multiple required ports', () {
        final result = verifier.verify(
          required: const RequiredCapabilities(
            ports: [
              PortRequirement(type: PortType.llm, required: true),
              PortRequirement(type: PortType.mcp, required: true),
              PortRequirement(type: PortType.knowledge, required: true),
            ],
          ),
          available: const ProvidedCapabilities(
            capabilities: [
              SkillCapability(name: 'port:llm'),
              // mcp and knowledge are missing
            ],
          ),
        );

        expect(result.satisfied, isFalse);
        expect(result.missing, hasLength(2));
        expect(result.missing.any((m) => m.contains('mcp')), isTrue);
        expect(result.missing.any((m) => m.contains('knowledge')), isTrue);
      });

      test('checks required skill dependencies', () {
        final result = verifier.verify(
          required: const RequiredCapabilities(
            skills: ['helper-skill'],
          ),
          available: const ProvidedCapabilities(
            capabilities: [SkillCapability(name: 'skill:helper-skill')],
          ),
        );

        expect(result.satisfied, isTrue);
      });

      test('fails when required skill dependency is missing', () {
        final result = verifier.verify(
          required: const RequiredCapabilities(
            skills: ['missing-skill'],
          ),
          available: const ProvidedCapabilities(capabilities: []),
        );

        expect(result.satisfied, isFalse);
        expect(result.missing, hasLength(1));
        expect(result.missing.first, contains('missing-skill'));
      });

      test('accumulates missing ports and missing skills', () {
        final result = verifier.verify(
          required: const RequiredCapabilities(
            ports: [PortRequirement(type: PortType.factGraph, required: true)],
            skills: ['helper-a', 'helper-b'],
          ),
          available: const ProvidedCapabilities(capabilities: []),
        );

        expect(result.satisfied, isFalse);
        // 1 missing port + 2 missing skills
        expect(result.missing, hasLength(3));
      });

      test('succeeds with no requirements', () {
        final result = verifier.verify(
          required: const RequiredCapabilities(),
          available: const ProvidedCapabilities(),
        );

        expect(result.satisfied, isTrue);
        expect(result.missing, isEmpty);
      });

      test('mix of required and optional ports', () {
        final result = verifier.verify(
          required: const RequiredCapabilities(
            ports: [
              PortRequirement(type: PortType.llm, required: true),
              PortRequirement(type: PortType.mcp, required: false),
              PortRequirement(type: PortType.factGraph, required: true),
            ],
          ),
          available: const ProvidedCapabilities(
            capabilities: [
              SkillCapability(name: 'port:llm'),
              SkillCapability(name: 'port:factGraph'),
            ],
          ),
        );

        // llm and factGraph are provided; mcp is optional so its absence is fine
        expect(result.satisfied, isTrue);
        expect(result.missing, isEmpty);
      });

      test('port name matching is exact (port:llm vs port:LLM)', () {
        final result = verifier.verify(
          required: const RequiredCapabilities(
            ports: [PortRequirement(type: PortType.llm, required: true)],
          ),
          available: const ProvidedCapabilities(
            capabilities: [SkillCapability(name: 'port:LLM')],
          ),
        );

        // PortType.llm.name is 'llm', not 'LLM'
        expect(result.satisfied, isFalse);
      });
    });
  });

  group('RuntimeVerifier', () {
    late RuntimeVerifier verifier;

    setUp(() {
      verifier = RuntimeVerifier();
    });

    group('verify', () {
      test('returns success when all required ports are available', () {
        final result = verifier.verify(
          required: const RequiredCapabilities(
            ports: [PortRequirement(type: PortType.llm, required: true)],
          ),
          availablePorts: {PortType.llm},
          availableSkills: {},
        );

        expect(result.satisfied, isTrue);
        expect(result.missing, isEmpty);
      });

      test('fails when required port is not available at runtime', () {
        final result = verifier.verify(
          required: const RequiredCapabilities(
            ports: [PortRequirement(type: PortType.knowledge, required: true)],
          ),
          availablePorts: {PortType.llm},
          availableSkills: {},
        );

        expect(result.satisfied, isFalse);
        expect(result.missing, hasLength(1));
        expect(result.missing.first, contains('knowledge'));
      });

      test('ignores optional ports when not available', () {
        final result = verifier.verify(
          required: const RequiredCapabilities(
            ports: [PortRequirement(type: PortType.mcp, required: false)],
          ),
          availablePorts: {},
          availableSkills: {},
        );

        expect(result.satisfied, isTrue);
      });

      test('checks required skills at runtime', () {
        final result = verifier.verify(
          required: const RequiredCapabilities(
            skills: ['skill-dep'],
          ),
          availablePorts: {},
          availableSkills: {'skill-dep'},
        );

        expect(result.satisfied, isTrue);
      });

      test('fails when required skill is not available', () {
        final result = verifier.verify(
          required: const RequiredCapabilities(
            skills: ['missing-dep'],
          ),
          availablePorts: {},
          availableSkills: {'other-skill'},
        );

        expect(result.satisfied, isFalse);
        expect(result.missing, hasLength(1));
        expect(result.missing.first, contains('missing-dep'));
      });

      test('accumulates all missing ports and skills', () {
        final result = verifier.verify(
          required: const RequiredCapabilities(
            ports: [
              PortRequirement(type: PortType.llm, required: true),
              PortRequirement(type: PortType.factGraph, required: true),
            ],
            skills: ['dep-a', 'dep-b'],
          ),
          availablePorts: {},
          availableSkills: {},
        );

        expect(result.satisfied, isFalse);
        expect(result.missing, hasLength(4));
      });

      test('succeeds with no requirements', () {
        final result = verifier.verify(
          required: const RequiredCapabilities(),
          availablePorts: {},
          availableSkills: {},
        );

        expect(result.satisfied, isTrue);
      });

      test('succeeds when all ports and skills are available', () {
        final result = verifier.verify(
          required: const RequiredCapabilities(
            ports: [
              PortRequirement(type: PortType.llm, required: true),
              PortRequirement(type: PortType.mcp, required: true),
            ],
            skills: ['helper'],
          ),
          availablePorts: {PortType.llm, PortType.mcp, PortType.knowledge},
          availableSkills: {'helper', 'extra-skill'},
        );

        expect(result.satisfied, isTrue);
      });

      test('mix of required and optional with partial availability', () {
        final result = verifier.verify(
          required: const RequiredCapabilities(
            ports: [
              PortRequirement(type: PortType.llm, required: true),
              PortRequirement(type: PortType.knowledge, required: false),
              PortRequirement(type: PortType.factGraph, required: true),
            ],
          ),
          availablePorts: {PortType.llm, PortType.factGraph},
          availableSkills: {},
        );

        expect(result.satisfied, isTrue);
      });
    });
  });

  group('VerificationResult', () {
    test('factory success creates satisfied result', () {
      final result = VerificationResult.success();

      expect(result.satisfied, isTrue);
      expect(result.missing, isEmpty);
      expect(result.warnings, isEmpty);
    });

    test('factory failure creates unsatisfied result with missing items', () {
      final result = VerificationResult.failure(['port:llm', 'skill:helper']);

      expect(result.satisfied, isFalse);
      expect(result.missing, hasLength(2));
      expect(result.missing, contains('port:llm'));
      expect(result.missing, contains('skill:helper'));
    });
  });
}
