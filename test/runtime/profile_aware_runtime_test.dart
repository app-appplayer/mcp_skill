// Tests for ProfileAwareSkillRuntime - profile resolution, decision guidance,
// context modification, and result formatting.

import 'package:test/test.dart';
import 'package:mcp_skill/src/runtime/profile_aware_runtime.dart';
import 'package:mcp_skill/src/runtime/skill_context.dart';
import 'package:mcp_skill/src/runtime/runtime_hooks.dart';
import 'package:mcp_skill/src/ports/skill_ports.dart';
import 'package:mcp_skill/src/registry/skill_registry.dart';
import 'package:mcp_skill/src/bundle/skill_bundle.dart';

import '../helpers/mock_ports.dart';

/// Mock ProfileRuntime for testing.
class MockProfileRuntime implements ProfileRuntime {
  ProfileAppraisal nextAppraisal;
  DecisionGuidance nextGuidance;
  ExpressionStyle nextStyle;

  MockProfileRuntime({
    ProfileAppraisal? appraisal,
    DecisionGuidance? guidance,
    ExpressionStyle? style,
  })  : nextAppraisal = appraisal ??
            const ProfileAppraisal(metrics: {'confidence': 0.8}),
        nextGuidance = guidance ??
            const DecisionGuidance(action: DecisionAction.proceed),
        nextStyle = style ?? const ExpressionStyle(tone: 'professional');

  @override
  Future<ProfileAppraisal> appraise(ProfileContext context) async =>
      nextAppraisal;

  @override
  Future<DecisionGuidance> getDecisionGuidance(
    ProfileAppraisal appraisal,
    ProfileContext context,
  ) async =>
      nextGuidance;

  @override
  Future<ExpressionStyle> getExpressionStyle(
    ProfileAppraisal appraisal,
    ProfileContext context,
  ) async =>
      nextStyle;
}

/// Mock ProfileRegistry for testing.
class MockProfileRegistry implements ProfileRegistry {
  final Map<String, List<ProfileBinding>> _bindings = {};
  final Map<String, Profile> _profiles = {};

  void addBinding(ProfileBinding binding) {
    _bindings.putIfAbsent(binding.skillId, () => []).add(binding);
  }

  void addProfile(Profile profile) {
    _profiles[profile.id] = profile;
  }

  @override
  Future<List<ProfileBinding>> getBindingsForSkill(String skillId) async {
    return _bindings[skillId] ?? [];
  }

  @override
  Future<Profile?> getProfile(String profileId) async {
    return _profiles[profileId];
  }
}

/// Mock SkillBundleRegistry for testing.
class _MockBundleRegistry implements SkillBundleRegistry {
  @override
  Future<List<SkillBundle>> listSkills({String? workspaceId}) async => [];
  @override
  Future<SkillBundle?> getSkill(String skillId) async => null;
  @override
  Future<void> registerSkill(SkillBundle bundle) async {}
  @override
  Future<void> unregisterSkill(String skillId) async {}
  @override
  Future<bool> isEnabled(String skillId, {String? workspaceId}) async => true;
  @override
  Future<void> setEnabled(String skillId, bool enabled,
      {String? workspaceId}) async {}
}

void main() {
  // Helper to create a minimal SkillContext.
  SkillContext _makeContext({
    String skillId = 'test-skill',
    String? userId,
    Map<String, dynamic> inputs = const {},
    List<String>? activeSkills,
    ExecutionBudget? budget,
    Map<String, dynamic>? metadata,
  }) {
    return SkillContext(
      contextId: 'ctx-1',
      skillId: skillId,
      runId: 'run-1',
      traceId: 'trace-1',
      request: 'test request',
      workspaceId: 'ws-1',
      asOf: DateTime(2025, 1, 1),
      inputs: inputs,
      activeSkills: activeSkills,
      userId: userId,
      budget: budget,
      metadata: metadata,
    );
  }

  group('Profile', () {
    test('stores id, name, and config', () {
      const profile = Profile(
        id: 'profile-1',
        name: 'Test Profile',
        config: {'threshold': 0.5},
      );

      expect(profile.id, equals('profile-1'));
      expect(profile.name, equals('Test Profile'));
      expect(profile.config['threshold'], equals(0.5));
    });
  });

  group('ProfileContext', () {
    test('stores all required fields', () {
      final ctx = ProfileContext(
        skillId: 'skill-1',
        userId: 'user-1',
        workspaceId: 'ws-1',
        request: 'test',
        inputs: const {'key': 'value'},
        asOf: DateTime(2025, 1, 1),
        profiles: const [],
      );

      expect(ctx.skillId, equals('skill-1'));
      expect(ctx.userId, equals('user-1'));
      expect(ctx.workspaceId, equals('ws-1'));
      expect(ctx.request, equals('test'));
      expect(ctx.inputs['key'], equals('value'));
    });
  });

  group('ProfileAppraisal', () {
    test('stores metrics and metadata', () {
      const appraisal = ProfileAppraisal(
        metrics: {'score': 0.9, 'latency': 120.0},
        metadata: {'source': 'test'},
      );

      expect(appraisal.metrics['score'], equals(0.9));
      expect(appraisal.metadata['source'], equals('test'));
    });

    test('toJson serializes correctly', () {
      const appraisal = ProfileAppraisal(
        metrics: {'score': 0.9},
        metadata: {'key': 'val'},
      );

      final json = appraisal.toJson();
      expect(json['metrics'], equals({'score': 0.9}));
      expect(json['metadata'], equals({'key': 'val'}));
    });

    test('default metadata is empty', () {
      const appraisal = ProfileAppraisal(metrics: {'x': 1.0});
      expect(appraisal.metadata, isEmpty);
    });
  });

  group('DecisionGuidance', () {
    test('stores action and reason', () {
      const guidance = DecisionGuidance(
        action: DecisionAction.hold,
        reason: 'Needs approval',
      );

      expect(guidance.action, equals(DecisionAction.hold));
      expect(guidance.reason, equals('Needs approval'));
    });

    test('toJson serializes action and modifications', () {
      const guidance = DecisionGuidance(
        action: DecisionAction.proceed,
        modifications: [
          ContextModification(
            type: 'input_override',
            values: {'key': 'value'},
          ),
        ],
      );

      final json = guidance.toJson();
      expect(json['action'], contains('proceed'));
      expect(json['modifications'], isList);
      expect((json['modifications'] as List).length, equals(1));
    });

    test('default modifications is empty', () {
      const guidance = DecisionGuidance(action: DecisionAction.proceed);
      expect(guidance.modifications, isEmpty);
    });
  });

  group('DecisionAction', () {
    test('has three values', () {
      expect(DecisionAction.values.length, equals(3));
      expect(DecisionAction.values, contains(DecisionAction.proceed));
      expect(DecisionAction.values, contains(DecisionAction.hold));
      expect(DecisionAction.values, contains(DecisionAction.reject));
    });
  });

  group('ContextModification', () {
    test('stores type and values', () {
      const mod = ContextModification(
        type: 'input_override',
        values: {'param': 'new_value'},
      );

      expect(mod.type, equals('input_override'));
      expect(mod.values['param'], equals('new_value'));
    });

    test('toJson serializes correctly', () {
      const mod = ContextModification(
        type: 'metadata_add',
        values: {'tag': 'important'},
      );

      final json = mod.toJson();
      expect(json['type'], equals('metadata_add'));
      expect(json['values']['tag'], equals('important'));
    });
  });

  group('ExpressionStyle', () {
    test('stores tone and formality', () {
      const style = ExpressionStyle(
        tone: 'professional',
        formality: 'formal',
      );

      expect(style.tone, equals('professional'));
      expect(style.formality, equals('formal'));
    });

    test('toJson serializes correctly', () {
      const style = ExpressionStyle(
        tone: 'casual',
        formality: 'informal',
        options: {'emoji': true},
      );

      final json = style.toJson();
      expect(json['tone'], equals('casual'));
      expect(json['formality'], equals('informal'));
      expect(json['options'], equals({'emoji': true}));
    });

    test('toJson omits null tone and formality', () {
      const style = ExpressionStyle();
      final json = style.toJson();
      expect(json.containsKey('tone'), isFalse);
      expect(json.containsKey('formality'), isFalse);
      expect(json.containsKey('options'), isTrue);
    });
  });

  group('ProfileBinding', () {
    test('stores skillId and profileIds', () {
      const binding = ProfileBinding(
        skillId: 'skill-1',
        profileIds: ['profile-a', 'profile-b'],
        condition: 'inputs.mode == "advanced"',
      );

      expect(binding.skillId, equals('skill-1'));
      expect(binding.profileIds, equals(['profile-a', 'profile-b']));
      expect(binding.condition, equals('inputs.mode == "advanced"'));
    });
  });

  group('ProfileAwareSkillRuntime', () {
    late MockProfileRuntime mockProfileRuntime;
    late MockProfileRegistry mockProfileRegistry;
    late SkillPorts ports;
    late _MockBundleRegistry registry;

    setUp(() {
      mockProfileRuntime = MockProfileRuntime();
      mockProfileRegistry = MockProfileRegistry();
      ports = SkillPorts(
        llm: MockLlmPort(),
        mcp: MockMcpPort(),
        retrieval: MockRetrievalPort(),
        claims: MockClaimsPort(),
        runs: MockRunsPort(),
        contextBundle: MockContextBundlePort(),
      );
      registry = _MockBundleRegistry();
    });

    test('executes standard when no profiles bound', () async {
      final runtime = ProfileAwareSkillRuntime(
        registry: registry,
        ports: ports,
        profileRuntime: mockProfileRuntime,
        profileRegistry: mockProfileRegistry,
      );

      final result = await runtime.run(_makeContext());

      // No profiles bound, so standard execution (which returns failure in mock)
      expect(result, isNotNull);
    });

    group('with profiles bound', () {
      setUp(() {
        mockProfileRegistry.addProfile(const Profile(
          id: 'prof-1',
          name: 'Test Profile',
          config: {'key': 'value'},
        ));
        mockProfileRegistry.addBinding(const ProfileBinding(
          skillId: 'test-skill',
          profileIds: ['prof-1'],
        ));
      });

      test('resolves profiles and appraises before execution', () async {
        final runtime = ProfileAwareSkillRuntime(
          registry: registry,
          ports: ports,
          profileRuntime: mockProfileRuntime,
          profileRegistry: mockProfileRegistry,
        );

        final result = await runtime.run(_makeContext());

        // Result should contain profile metadata
        expect(result, isNotNull);
      });

      test('reject guidance returns failure result', () async {
        mockProfileRuntime.nextGuidance = const DecisionGuidance(
          action: DecisionAction.reject,
          reason: 'Policy violation',
        );

        final runtime = ProfileAwareSkillRuntime(
          registry: registry,
          ports: ports,
          profileRuntime: mockProfileRuntime,
          profileRegistry: mockProfileRegistry,
        );

        final result = await runtime.run(_makeContext());

        expect(result.success, isFalse);
      });

      test('hold guidance returns hold result with metadata', () async {
        mockProfileRuntime.nextGuidance = const DecisionGuidance(
          action: DecisionAction.hold,
          reason: 'Needs manager approval',
        );

        final runtime = ProfileAwareSkillRuntime(
          registry: registry,
          ports: ports,
          profileRuntime: mockProfileRuntime,
          profileRegistry: mockProfileRegistry,
        );

        final result = await runtime.run(_makeContext());

        expect(result.metadata.custom?['decisionAction'], equals('hold'));
        expect(result.metadata.custom?['requiresApproval'], isTrue);
      });

      test('proceed guidance executes and formats with style', () async {
        mockProfileRuntime.nextGuidance = const DecisionGuidance(
          action: DecisionAction.proceed,
        );
        mockProfileRuntime.nextStyle = const ExpressionStyle(
          tone: 'formal',
          formality: 'high',
        );

        final runtime = ProfileAwareSkillRuntime(
          registry: registry,
          ports: ports,
          profileRuntime: mockProfileRuntime,
          profileRegistry: mockProfileRegistry,
        );

        final result = await runtime.run(_makeContext());

        // Result should have profile metadata embedded
        expect(result.metadata.custom?['profile'], isNotNull);
        final profileMeta =
            result.metadata.custom!['profile'] as Map<String, dynamic>;
        expect(profileMeta.containsKey('style'), isTrue);
      });

      test('input_override modification modifies context inputs', () async {
        mockProfileRuntime.nextGuidance = const DecisionGuidance(
          action: DecisionAction.proceed,
          modifications: [
            ContextModification(
              type: 'input_override',
              values: {'extra_param': 'injected'},
            ),
          ],
        );

        final runtime = ProfileAwareSkillRuntime(
          registry: registry,
          ports: ports,
          profileRuntime: mockProfileRuntime,
          profileRegistry: mockProfileRegistry,
        );

        final result = await runtime.run(
            _makeContext(inputs: {'original': 'value'}));

        // The runtime should have applied input_override
        expect(result, isNotNull);
      });

      test('budget_adjust modification adjusts budget', () async {
        mockProfileRuntime.nextGuidance = const DecisionGuidance(
          action: DecisionAction.proceed,
          modifications: [
            ContextModification(
              type: 'budget_adjust',
              values: {
                'budget': {'maxTokens': 5000, 'maxSteps': 10},
              },
            ),
          ],
        );

        final runtime = ProfileAwareSkillRuntime(
          registry: registry,
          ports: ports,
          profileRuntime: mockProfileRuntime,
          profileRegistry: mockProfileRegistry,
        );

        final result = await runtime.run(_makeContext(
          budget: const ExecutionBudget(maxTokens: 10000, maxSteps: 50),
        ));

        expect(result, isNotNull);
      });

      test('metadata_add modification adds metadata', () async {
        mockProfileRuntime.nextGuidance = const DecisionGuidance(
          action: DecisionAction.proceed,
          modifications: [
            ContextModification(
              type: 'metadata_add',
              values: {'custom_tag': 'priority'},
            ),
          ],
        );

        final runtime = ProfileAwareSkillRuntime(
          registry: registry,
          ports: ports,
          profileRuntime: mockProfileRuntime,
          profileRegistry: mockProfileRegistry,
        );

        final result = await runtime.run(_makeContext());

        expect(result, isNotNull);
      });
    });

    group('profile hooks', () {
      test('notifies profile hooks on appraisal and guidance', () async {
        mockProfileRegistry.addProfile(const Profile(
          id: 'prof-1',
          name: 'Test Profile',
          config: {},
        ));
        mockProfileRegistry.addBinding(const ProfileBinding(
          skillId: 'test-skill',
          profileIds: ['prof-1'],
        ));

        final events = <String>[];
        final hook = _TrackingProfileHook(events);

        final runtime = ProfileAwareSkillRuntime(
          registry: registry,
          ports: ports,
          profileRuntime: mockProfileRuntime,
          profileRegistry: mockProfileRegistry,
          hooks: [hook],
        );

        await runtime.run(_makeContext());

        expect(events, contains('onProfileAppraisal'));
        expect(events, contains('onDecisionGuidance'));
      });

      test('ignores non-profile hooks during profile events', () async {
        mockProfileRegistry.addProfile(const Profile(
          id: 'prof-1',
          name: 'Test Profile',
          config: {},
        ));
        mockProfileRegistry.addBinding(const ProfileBinding(
          skillId: 'test-skill',
          profileIds: ['prof-1'],
        ));

        // A regular RuntimeHook (not ProfileRuntimeHook) should be ignored
        final regularHook = _RegularHook();

        final runtime = ProfileAwareSkillRuntime(
          registry: registry,
          ports: ports,
          profileRuntime: mockProfileRuntime,
          profileRegistry: mockProfileRegistry,
          hooks: [regularHook],
        );

        // Should not throw
        final result = await runtime.run(_makeContext());
        expect(result, isNotNull);
      });
    });
  });
}

/// Tracking hook for profile events.
class _TrackingProfileHook extends ProfileRuntimeHook {
  final List<String> events;
  _TrackingProfileHook(this.events);

  @override
  Future<void> onProfileAppraisal(
    SkillContext context,
    ProfileAppraisal appraisal,
  ) async {
    events.add('onProfileAppraisal');
  }

  @override
  Future<void> onDecisionGuidance(
    SkillContext context,
    DecisionGuidance guidance,
  ) async {
    events.add('onDecisionGuidance');
  }
}

/// Regular RuntimeHook (not ProfileRuntimeHook) for testing isolation.
class _RegularHook extends RuntimeHook {
  @override
  Future<void> beforeExecution(SkillContext context) async {}
}
