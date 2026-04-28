import 'package:test/test.dart';
import 'package:mcp_skill/src/runtime/skill_result.dart';

void main() {
  group('ClaimType', () {
    test('has all expected values', () {
      expect(ClaimType.values, contains(ClaimType.fact));
      expect(ClaimType.values, contains(ClaimType.conclusion));
      expect(ClaimType.values, contains(ClaimType.observation));
      expect(ClaimType.values, contains(ClaimType.prediction));
      expect(ClaimType.values, contains(ClaimType.recommendation));
      expect(ClaimType.values, contains(ClaimType.speculation));
    });

    test('fromString returns correct value', () {
      expect(ClaimType.fromString('fact'), equals(ClaimType.fact));
      expect(ClaimType.fromString('conclusion'), equals(ClaimType.conclusion));
      expect(ClaimType.fromString('observation'), equals(ClaimType.observation));
      expect(ClaimType.fromString('prediction'), equals(ClaimType.prediction));
      expect(ClaimType.fromString('recommendation'), equals(ClaimType.recommendation));
      expect(ClaimType.fromString('speculation'), equals(ClaimType.speculation));
    });

    test('fromString returns fact for unknown values', () {
      expect(ClaimType.fromString('unknown'), equals(ClaimType.fact));
      expect(ClaimType.fromString(''), equals(ClaimType.fact));
    });
  });

  group('Claim', () {
    test('constructor creates instance with required fields', () {
      const claim = Claim(
        id: 'claim-1',
        workspaceId: 'test-workspace',
        type: ClaimType.fact,
        text: 'Test claim',
        evidenceRefs: ['ref-1'],
        confidence: 0.9,
      );

      expect(claim.id, equals('claim-1'));
      expect(claim.type, equals(ClaimType.fact));
      expect(claim.text, equals('Test claim'));
      expect(claim.evidenceRefs, equals(['ref-1']));
      expect(claim.confidence, equals(0.9));
      expect(claim.value, isNull);
      expect(claim.metadata, isNull);
    });

    test('constructor creates instance with all fields', () {
      const claim = Claim(
        id: 'claim-1',
        workspaceId: 'test-workspace',
        type: ClaimType.conclusion,
        text: 'Test claim',
        value: {'key': 'value'},
        evidenceRefs: ['ref-1', 'ref-2'],
        confidence: 0.85,
        metadata: {'source': 'test'},
      );

      expect(claim.value, equals({'key': 'value'}));
      expect(claim.metadata, equals({'source': 'test'}));
    });

    test('fromJson creates instance from JSON', () {
      final json = {
        'id': 'claim-1',
        'type': 'conclusion',
        'text': 'Test claim',
        'value': 42,
        'evidenceRefs': ['ref-1'],
        'confidence': 0.8,
        'metadata': {'key': 'value'},
      };

      final claim = Claim.fromJson(json);

      expect(claim.id, equals('claim-1'));
      expect(claim.type, equals(ClaimType.conclusion));
      expect(claim.text, equals('Test claim'));
      expect(claim.value, equals(42));
      expect(claim.evidenceRefs, equals(['ref-1']));
      expect(claim.confidence, equals(0.8));
      expect(claim.metadata, equals({'key': 'value'}));
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final claim = Claim.fromJson(json);

      expect(claim.id, equals(''));
      expect(claim.type, equals(ClaimType.fact));
      expect(claim.text, equals(''));
      expect(claim.evidenceRefs, isEmpty);
      expect(claim.confidence, equals(0.0));
    });

    test('toJson converts instance to JSON', () {
      const claim = Claim(
        id: 'claim-1',
        workspaceId: 'test-workspace',
        type: ClaimType.prediction,
        text: 'Test claim',
        value: 'structured data',
        evidenceRefs: ['ref-1'],
        confidence: 0.75,
        metadata: {'key': 'value'},
      );

      final json = claim.toJson();

      expect(json['id'], equals('claim-1'));
      expect(json['type'], equals('prediction'));
      expect(json['text'], equals('Test claim'));
      expect(json['value'], equals('structured data'));
      expect(json['evidenceRefs'], equals(['ref-1']));
      expect(json['confidence'], equals(0.75));
      expect(json['metadata'], equals({'key': 'value'}));
    });

    test('toJson excludes null fields', () {
      const claim = Claim(
        id: 'claim-1',
        workspaceId: 'test-workspace',
        type: ClaimType.fact,
        text: 'Test claim',
        evidenceRefs: [],
        confidence: 0.9,
      );

      final json = claim.toJson();

      expect(json.containsKey('value'), isFalse);
      expect(json.containsKey('metadata'), isFalse);
    });

    test('toString returns expected string representation', () {
      const claim = Claim(
        id: 'claim-1',
        workspaceId: 'test-workspace',
        type: ClaimType.fact,
        text: 'Test claim',
        evidenceRefs: [],
        confidence: 0.9,
      );

      final str = claim.toString();

      expect(str, contains('Claim'));
      expect(str, contains('claim-1'));
      expect(str, contains('Test claim'));
      expect(str, contains('pending'));
    });
  });

  group('ActionStatus', () {
    test('has all expected values', () {
      expect(ActionStatus.values, contains(ActionStatus.pending));
      expect(ActionStatus.values, contains(ActionStatus.executed));
      expect(ActionStatus.values, contains(ActionStatus.failed));
      expect(ActionStatus.values, contains(ActionStatus.skipped));
    });

    test('fromString returns correct value', () {
      expect(ActionStatus.fromString('pending'), equals(ActionStatus.pending));
      expect(ActionStatus.fromString('executed'), equals(ActionStatus.executed));
      expect(ActionStatus.fromString('failed'), equals(ActionStatus.failed));
      expect(ActionStatus.fromString('skipped'), equals(ActionStatus.skipped));
    });

    test('fromString returns pending for unknown values', () {
      expect(ActionStatus.fromString('unknown'), equals(ActionStatus.pending));
      expect(ActionStatus.fromString(''), equals(ActionStatus.pending));
    });
  });

  group('SkillAction', () {
    test('constructor creates instance with required fields', () {
      const action = SkillAction(
        type: 'execute',
        description: 'Execute command',
        status: ActionStatus.pending,
      );

      expect(action.type, equals('execute'));
      expect(action.description, equals('Execute command'));
      expect(action.status, equals(ActionStatus.pending));
      expect(action.toolRef, isNull);
      expect(action.args, isNull);
      expect(action.result, isNull);
      expect(action.error, isNull);
    });

    test('pending factory creates pending action', () {
      final action = SkillAction.pending(
        type: 'tool_call',
        description: 'Call tool',
        toolRef: 'tool-1',
        args: {'arg1': 'value1'},
      );

      expect(action.type, equals('tool_call'));
      expect(action.description, equals('Call tool'));
      expect(action.status, equals(ActionStatus.pending));
      expect(action.toolRef, equals('tool-1'));
      expect(action.args, equals({'arg1': 'value1'}));
    });

    test('fromJson creates instance from JSON', () {
      final json = {
        'type': 'execute',
        'description': 'Execute command',
        'toolRef': 'tool-1',
        'args': {'key': 'value'},
        'status': 'executed',
        'result': 'success',
        'error': null,
      };

      final action = SkillAction.fromJson(json);

      expect(action.type, equals('execute'));
      expect(action.description, equals('Execute command'));
      expect(action.toolRef, equals('tool-1'));
      expect(action.args, equals({'key': 'value'}));
      expect(action.status, equals(ActionStatus.executed));
      expect(action.result, equals('success'));
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final action = SkillAction.fromJson(json);

      expect(action.type, equals(''));
      expect(action.description, equals(''));
      expect(action.status, equals(ActionStatus.pending));
    });

    test('toJson converts instance to JSON', () {
      const action = SkillAction(
        type: 'execute',
        description: 'Execute command',
        toolRef: 'tool-1',
        args: {'key': 'value'},
        status: ActionStatus.failed,
        result: 'output',
        error: 'Error occurred',
      );

      final json = action.toJson();

      expect(json['type'], equals('execute'));
      expect(json['description'], equals('Execute command'));
      expect(json['toolRef'], equals('tool-1'));
      expect(json['args'], equals({'key': 'value'}));
      expect(json['status'], equals('failed'));
      expect(json['result'], equals('output'));
      expect(json['error'], equals('Error occurred'));
    });

    test('toJson excludes null fields', () {
      const action = SkillAction(
        type: 'execute',
        description: 'Execute command',
        status: ActionStatus.pending,
      );

      final json = action.toJson();

      expect(json.containsKey('toolRef'), isFalse);
      expect(json.containsKey('args'), isFalse);
      expect(json.containsKey('result'), isFalse);
      expect(json.containsKey('error'), isFalse);
    });

    test('copyWithStatus creates copy with new status', () {
      const original = SkillAction(
        type: 'execute',
        description: 'Execute command',
        status: ActionStatus.pending,
      );

      final updated = original.copyWithStatus(
        ActionStatus.executed,
        result: 'success',
      );

      expect(updated.type, equals('execute'));
      expect(updated.description, equals('Execute command'));
      expect(updated.status, equals(ActionStatus.executed));
      expect(updated.result, equals('success'));
    });

    test('copyWithStatus can set error', () {
      const original = SkillAction(
        type: 'execute',
        description: 'Execute command',
        status: ActionStatus.pending,
      );

      final updated = original.copyWithStatus(
        ActionStatus.failed,
        error: 'Error occurred',
      );

      expect(updated.status, equals(ActionStatus.failed));
      expect(updated.error, equals('Error occurred'));
    });

    test('toString returns expected string representation', () {
      const action = SkillAction(
        type: 'execute',
        description: 'Execute command',
        status: ActionStatus.pending,
      );

      final str = action.toString();

      expect(str, contains('SkillAction'));
      expect(str, contains('execute'));
      expect(str, contains('pending'));
    });
  });

  group('Finding', () {
    test('constructor creates instance with required fields', () {
      const finding = Finding(
        type: 'strength',
        dimensionId: 'quality',
        description: 'Good code quality',
      );

      expect(finding.type, equals('strength'));
      expect(finding.dimensionId, equals('quality'));
      expect(finding.description, equals('Good code quality'));
      expect(finding.evidenceRefs, isEmpty);
      expect(finding.impact, isNull);
    });

    test('constructor creates instance with all fields', () {
      const finding = Finding(
        type: 'weakness',
        dimensionId: 'performance',
        description: 'Slow execution',
        evidenceRefs: ['ref-1', 'ref-2'],
        impact: 0.8,
      );

      expect(finding.evidenceRefs, equals(['ref-1', 'ref-2']));
      expect(finding.impact, equals(0.8));
    });

    test('fromJson creates instance from JSON', () {
      final json = {
        'type': 'suggestion',
        'dimensionId': 'maintainability',
        'description': 'Consider refactoring',
        'evidenceRefs': ['ref-1'],
        'impact': 0.5,
      };

      final finding = Finding.fromJson(json);

      expect(finding.type, equals('suggestion'));
      expect(finding.dimensionId, equals('maintainability'));
      expect(finding.description, equals('Consider refactoring'));
      expect(finding.evidenceRefs, equals(['ref-1']));
      expect(finding.impact, equals(0.5));
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final finding = Finding.fromJson(json);

      expect(finding.type, equals(''));
      expect(finding.dimensionId, equals(''));
      expect(finding.description, equals(''));
      expect(finding.evidenceRefs, isEmpty);
    });

    test('toJson converts instance to JSON', () {
      const finding = Finding(
        type: 'strength',
        dimensionId: 'quality',
        description: 'Good quality',
        evidenceRefs: ['ref-1'],
        impact: 0.9,
      );

      final json = finding.toJson();

      expect(json['type'], equals('strength'));
      expect(json['dimensionId'], equals('quality'));
      expect(json['description'], equals('Good quality'));
      expect(json['evidenceRefs'], equals(['ref-1']));
      expect(json['impact'], equals(0.9));
    });

    test('toJson excludes empty evidenceRefs and null impact', () {
      const finding = Finding(
        type: 'strength',
        dimensionId: 'quality',
        description: 'Good quality',
      );

      final json = finding.toJson();

      expect(json.containsKey('evidenceRefs'), isFalse);
      expect(json.containsKey('impact'), isFalse);
    });
  });

  group('RubricScore', () {
    test('constructor creates instance with required fields', () {
      const score = RubricScore(
        rubricId: 'rubric-1',
        dimensionScores: {'quality': 0.8, 'performance': 0.9},
        totalScore: 85.0,
        grade: 'A',
      );

      expect(score.rubricId, equals('rubric-1'));
      expect(score.dimensionScores, equals({'quality': 0.8, 'performance': 0.9}));
      expect(score.totalScore, equals(85.0));
      expect(score.grade, equals('A'));
      expect(score.findings, isNull);
    });

    test('fromJson creates instance from JSON', () {
      final json = {
        'rubricId': 'rubric-1',
        'dimensionScores': {'quality': 0.8},
        'totalScore': 80.0,
        'grade': 'B',
        'findings': [
          {
            'type': 'strength',
            'dimensionId': 'quality',
            'description': 'Good quality',
          }
        ],
      };

      final score = RubricScore.fromJson(json);

      expect(score.rubricId, equals('rubric-1'));
      expect(score.dimensionScores, equals({'quality': 0.8}));
      expect(score.totalScore, equals(80.0));
      expect(score.grade, equals('B'));
      expect(score.findings, hasLength(1));
      expect(score.findings!.first.type, equals('strength'));
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final score = RubricScore.fromJson(json);

      expect(score.rubricId, equals(''));
      expect(score.dimensionScores, isEmpty);
      expect(score.totalScore, equals(0.0));
      expect(score.grade, equals(''));
    });

    test('toJson converts instance to JSON', () {
      const finding = Finding(
        type: 'strength',
        dimensionId: 'quality',
        description: 'Good quality',
      );
      const score = RubricScore(
        rubricId: 'rubric-1',
        dimensionScores: {'quality': 0.9},
        totalScore: 90.0,
        grade: 'A',
        findings: [finding],
      );

      final json = score.toJson();

      expect(json['rubricId'], equals('rubric-1'));
      expect(json['dimensionScores'], equals({'quality': 0.9}));
      expect(json['totalScore'], equals(90.0));
      expect(json['grade'], equals('A'));
      expect(json['findings'], isA<List>());
    });

    test('passed returns true when score >= 60', () {
      const passing = RubricScore(
        rubricId: 'rubric-1',
        dimensionScores: {},
        totalScore: 60.0,
        grade: 'D',
      );

      const highScore = RubricScore(
        rubricId: 'rubric-1',
        dimensionScores: {},
        totalScore: 90.0,
        grade: 'A',
      );

      expect(passing.passed, isTrue);
      expect(highScore.passed, isTrue);
    });

    test('passed returns false when score < 60', () {
      const failing = RubricScore(
        rubricId: 'rubric-1',
        dimensionScores: {},
        totalScore: 59.0,
        grade: 'F',
      );

      expect(failing.passed, isFalse);
    });

    test('toString returns expected string representation', () {
      const score = RubricScore(
        rubricId: 'rubric-1',
        dimensionScores: {},
        totalScore: 85.0,
        grade: 'A',
      );

      final str = score.toString();

      expect(str, contains('RubricScore'));
      expect(str, contains('rubric-1'));
      expect(str, contains('85.0'));
      expect(str, contains('A'));
    });
  });

  group('Conflict', () {
    test('constructor creates instance with required fields', () {
      const conflict = Conflict(
        id: 'conflict-1',
        type: 'contradiction',
        description: 'Claims contradict each other',
        claimIds: ['claim-1', 'claim-2'],
        severity: 'high',
      );

      expect(conflict.id, equals('conflict-1'));
      expect(conflict.type, equals('contradiction'));
      expect(conflict.description, equals('Claims contradict each other'));
      expect(conflict.claimIds, equals(['claim-1', 'claim-2']));
      expect(conflict.severity, equals('high'));
      expect(conflict.resolution, isNull);
    });

    test('fromJson creates instance from JSON', () {
      final json = {
        'id': 'conflict-1',
        'type': 'inconsistency',
        'description': 'Data inconsistent',
        'claimIds': ['claim-1'],
        'severity': 'medium',
        'resolution': 'Resolved by using latest data',
      };

      final conflict = Conflict.fromJson(json);

      expect(conflict.id, equals('conflict-1'));
      expect(conflict.type, equals('inconsistency'));
      expect(conflict.resolution, equals('Resolved by using latest data'));
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final conflict = Conflict.fromJson(json);

      expect(conflict.id, equals(''));
      expect(conflict.type, equals(''));
      expect(conflict.description, equals(''));
      expect(conflict.claimIds, isEmpty);
      expect(conflict.severity, equals('medium'));
    });

    test('toJson converts instance to JSON', () {
      const conflict = Conflict(
        id: 'conflict-1',
        type: 'contradiction',
        description: 'Contradictory claims',
        claimIds: ['claim-1', 'claim-2'],
        severity: 'high',
        resolution: 'Chose latest claim',
      );

      final json = conflict.toJson();

      expect(json['id'], equals('conflict-1'));
      expect(json['type'], equals('contradiction'));
      expect(json['description'], equals('Contradictory claims'));
      expect(json['claimIds'], equals(['claim-1', 'claim-2']));
      expect(json['severity'], equals('high'));
      expect(json['resolution'], equals('Chose latest claim'));
    });

    test('toJson excludes null resolution', () {
      const conflict = Conflict(
        id: 'conflict-1',
        type: 'contradiction',
        description: 'Contradictory claims',
        claimIds: [],
        severity: 'low',
      );

      final json = conflict.toJson();

      expect(json.containsKey('resolution'), isFalse);
    });
  });

  group('Artifact', () {
    test('constructor creates instance with required fields', () {
      const artifact = Artifact(
        id: 'artifact-1',
        type: 'document',
        content: 'Document content',
      );

      expect(artifact.id, equals('artifact-1'));
      expect(artifact.type, equals('document'));
      expect(artifact.content, equals('Document content'));
      expect(artifact.mimeType, isNull);
      expect(artifact.fileName, isNull);
      expect(artifact.metadata, isNull);
    });

    test('constructor creates instance with all fields', () {
      const artifact = Artifact(
        id: 'artifact-1',
        type: 'file',
        content: 'content',
        mimeType: 'application/json',
        fileName: 'data.json',
        metadata: {'size': 1024},
      );

      expect(artifact.mimeType, equals('application/json'));
      expect(artifact.fileName, equals('data.json'));
      expect(artifact.metadata, equals({'size': 1024}));
    });

    test('fromJson creates instance from JSON', () {
      final json = {
        'id': 'artifact-1',
        'type': 'image',
        'content': 'base64data',
        'mimeType': 'image/png',
        'fileName': 'screenshot.png',
        'metadata': {'width': 800, 'height': 600},
      };

      final artifact = Artifact.fromJson(json);

      expect(artifact.id, equals('artifact-1'));
      expect(artifact.type, equals('image'));
      expect(artifact.content, equals('base64data'));
      expect(artifact.mimeType, equals('image/png'));
      expect(artifact.fileName, equals('screenshot.png'));
      expect(artifact.metadata, equals({'width': 800, 'height': 600}));
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final artifact = Artifact.fromJson(json);

      expect(artifact.id, equals(''));
      expect(artifact.type, equals(''));
      expect(artifact.content, isNull);
    });

    test('toJson converts instance to JSON', () {
      const artifact = Artifact(
        id: 'artifact-1',
        type: 'document',
        content: 'content',
        mimeType: 'text/plain',
        fileName: 'doc.txt',
        metadata: {'key': 'value'},
      );

      final json = artifact.toJson();

      expect(json['id'], equals('artifact-1'));
      expect(json['type'], equals('document'));
      expect(json['content'], equals('content'));
      expect(json['mimeType'], equals('text/plain'));
      expect(json['fileName'], equals('doc.txt'));
      expect(json['metadata'], equals({'key': 'value'}));
    });

    test('toJson excludes null fields', () {
      const artifact = Artifact(
        id: 'artifact-1',
        type: 'document',
        content: 'content',
      );

      final json = artifact.toJson();

      expect(json.containsKey('mimeType'), isFalse);
      expect(json.containsKey('fileName'), isFalse);
      expect(json.containsKey('metadata'), isFalse);
    });
  });

  group('ExecutionMetadata', () {
    test('constructor creates instance with required fields', () {
      final startedAt = DateTime(2024, 1, 15, 10, 0);
      final finishedAt = DateTime(2024, 1, 15, 10, 5);
      final metadata = ExecutionMetadata(
        skillId: 'skill-1',
        skillVersion: '1.0.0',
        procedureId: 'proc-1',
        startedAt: startedAt,
        finishedAt: finishedAt,
        duration: const Duration(minutes: 5),
        stepsExecuted: 10,
        toolsCalled: ['tool-1', 'tool-2'],
      );

      expect(metadata.skillId, equals('skill-1'));
      expect(metadata.skillVersion, equals('1.0.0'));
      expect(metadata.procedureId, equals('proc-1'));
      expect(metadata.startedAt, equals(startedAt));
      expect(metadata.finishedAt, equals(finishedAt));
      expect(metadata.duration, equals(const Duration(minutes: 5)));
      expect(metadata.stepsExecuted, equals(10));
      expect(metadata.toolsCalled, equals(['tool-1', 'tool-2']));
      expect(metadata.llmUsage, isNull);
      expect(metadata.custom, isNull);
    });

    test('create factory computes duration', () {
      final startedAt = DateTime(2024, 1, 15, 10, 0);
      final finishedAt = DateTime(2024, 1, 15, 10, 2);
      final metadata = ExecutionMetadata.create(
        skillId: 'skill-1',
        skillVersion: '1.0.0',
        procedureId: 'proc-1',
        startedAt: startedAt,
        finishedAt: finishedAt,
        stepsExecuted: 5,
      );

      expect(metadata.duration, equals(const Duration(minutes: 2)));
    });

    test('create factory uses current time when finishedAt not provided', () {
      final startedAt = DateTime.now().subtract(const Duration(seconds: 1));
      final metadata = ExecutionMetadata.create(
        skillId: 'skill-1',
        skillVersion: '1.0.0',
        procedureId: 'proc-1',
        startedAt: startedAt,
        stepsExecuted: 1,
      );

      expect(metadata.duration.inMilliseconds, greaterThanOrEqualTo(1000));
    });

    test('fromJson creates instance from JSON', () {
      final json = {
        'skillId': 'skill-1',
        'skillVersion': '2.0.0',
        'procedureId': 'proc-1',
        'startedAt': '2024-01-15T10:00:00.000',
        'finishedAt': '2024-01-15T10:03:00.000',
        'durationMs': 180000,
        'stepsExecuted': 15,
        'toolsCalled': ['tool-1'],
        'custom': {'key': 'value'},
      };

      final metadata = ExecutionMetadata.fromJson(json);

      expect(metadata.skillId, equals('skill-1'));
      expect(metadata.skillVersion, equals('2.0.0'));
      expect(metadata.duration, equals(const Duration(milliseconds: 180000)));
      expect(metadata.stepsExecuted, equals(15));
      expect(metadata.custom, equals({'key': 'value'}));
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final metadata = ExecutionMetadata.fromJson(json);

      expect(metadata.skillId, equals(''));
      expect(metadata.skillVersion, equals(''));
      expect(metadata.procedureId, equals(''));
      expect(metadata.stepsExecuted, equals(0));
      expect(metadata.toolsCalled, isEmpty);
    });

    test('toJson converts instance to JSON', () {
      final startedAt = DateTime(2024, 1, 15, 10, 0);
      final finishedAt = DateTime(2024, 1, 15, 10, 5);
      final metadata = ExecutionMetadata(
        skillId: 'skill-1',
        skillVersion: '1.0.0',
        procedureId: 'proc-1',
        startedAt: startedAt,
        finishedAt: finishedAt,
        duration: const Duration(minutes: 5),
        stepsExecuted: 10,
        toolsCalled: ['tool-1'],
        custom: {'key': 'value'},
      );

      final json = metadata.toJson();

      expect(json['skillId'], equals('skill-1'));
      expect(json['skillVersion'], equals('1.0.0'));
      expect(json['procedureId'], equals('proc-1'));
      expect(json['startedAt'], equals(startedAt.toIso8601String()));
      expect(json['finishedAt'], equals(finishedAt.toIso8601String()));
      expect(json['durationMs'], equals(300000));
      expect(json['stepsExecuted'], equals(10));
      expect(json['toolsCalled'], equals(['tool-1']));
      expect(json['custom'], equals({'key': 'value'}));
    });

    test('toString returns expected string representation', () {
      final metadata = ExecutionMetadata(
        skillId: 'skill-1',
        skillVersion: '1.0.0',
        procedureId: 'proc-1',
        startedAt: DateTime.now(),
        finishedAt: DateTime.now(),
        duration: const Duration(seconds: 30),
        stepsExecuted: 5,
        toolsCalled: [],
      );

      final str = metadata.toString();

      expect(str, contains('ExecutionMetadata'));
      expect(str, contains('skill-1'));
      expect(str, contains('5'));
    });
  });

  group('StepResult', () {
    test('constructor creates instance with required fields', () {
      const result = StepResult(
        stepId: 'step-1',
        result: 'step output',
      );

      expect(result.stepId, equals('step-1'));
      expect(result.result, equals('step output'));
      expect(result.claims, isEmpty);
      expect(result.evidenceRefs, isEmpty);
      expect(result.toolCalled, isNull);
      expect(result.metadata, isNull);
    });

    test('constructor creates instance with all fields', () {
      const claim = Claim(
        id: 'claim-1',
        workspaceId: 'test-workspace',
        type: ClaimType.fact,
        text: 'Test',
        evidenceRefs: [],
        confidence: 0.9,
      );
      const result = StepResult(
        stepId: 'step-1',
        result: 'output',
        claims: [claim],
        evidenceRefs: ['ref-1'],
        toolCalled: 'tool-1',
        metadata: {'key': 'value'},
      );

      expect(result.claims, hasLength(1));
      expect(result.evidenceRefs, equals(['ref-1']));
      expect(result.toolCalled, equals('tool-1'));
      expect(result.metadata, equals({'key': 'value'}));
    });

    test('fromJson creates instance from JSON', () {
      final json = {
        'stepId': 'step-1',
        'result': {'key': 'value'},
        'claims': [
          {
            'id': 'claim-1',
            'type': 'fact',
            'text': 'Test claim',
            'evidenceRefs': [],
            'confidence': 0.8,
          }
        ],
        'evidenceRefs': ['ref-1'],
        'toolCalled': 'tool-1',
        'metadata': {'meta': 'data'},
      };

      final result = StepResult.fromJson(json);

      expect(result.stepId, equals('step-1'));
      expect(result.result, equals({'key': 'value'}));
      expect(result.claims, hasLength(1));
      expect(result.evidenceRefs, equals(['ref-1']));
      expect(result.toolCalled, equals('tool-1'));
      expect(result.metadata, equals({'meta': 'data'}));
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final result = StepResult.fromJson(json);

      expect(result.stepId, equals(''));
      expect(result.result, isNull);
      expect(result.claims, isEmpty);
      expect(result.evidenceRefs, isEmpty);
    });

    test('toJson converts instance to JSON', () {
      const claim = Claim(
        id: 'claim-1',
        workspaceId: 'test-workspace',
        type: ClaimType.fact,
        text: 'Test',
        evidenceRefs: [],
        confidence: 0.9,
      );
      const result = StepResult(
        stepId: 'step-1',
        result: 'output',
        claims: [claim],
        evidenceRefs: ['ref-1'],
        toolCalled: 'tool-1',
        metadata: {'key': 'value'},
      );

      final json = result.toJson();

      expect(json['stepId'], equals('step-1'));
      expect(json['result'], equals('output'));
      expect(json['claims'], isA<List>());
      expect(json['evidenceRefs'], equals(['ref-1']));
      expect(json['toolCalled'], equals('tool-1'));
      expect(json['metadata'], equals({'key': 'value'}));
    });

    test('toJson excludes empty claims and evidenceRefs', () {
      const result = StepResult(
        stepId: 'step-1',
        result: 'output',
      );

      final json = result.toJson();

      expect(json.containsKey('claims'), isFalse);
      expect(json.containsKey('evidenceRefs'), isFalse);
      expect(json.containsKey('toolCalled'), isFalse);
      expect(json.containsKey('metadata'), isFalse);
    });

    test('toString returns expected string representation', () {
      const result = StepResult(
        stepId: 'step-1',
        result: 'output',
        claims: [],
        evidenceRefs: ['ref-1', 'ref-2'],
      );

      final str = result.toString();

      expect(str, contains('StepResult'));
      expect(str, contains('step-1'));
      expect(str, contains('0'));
      expect(str, contains('2'));
    });
  });

  group('SkillResult', () {
    ExecutionMetadata createMetadata() {
      return ExecutionMetadata(
        skillId: 'skill-1',
        skillVersion: '1.0.0',
        procedureId: 'proc-1',
        startedAt: DateTime.now(),
        finishedAt: DateTime.now(),
        duration: const Duration(seconds: 30),
        stepsExecuted: 5,
        toolsCalled: [],
      );
    }

    test('constructor creates instance with required fields', () {
      final metadata = createMetadata();
      final asOf = DateTime(2024, 1, 15);
      final result = SkillResult(
        claims: const [],
        evidenceRefs: const [],
        confidence: 0.9,
        asOf: asOf,
        metadata: metadata,
      );

      expect(result.claims, isEmpty);
      expect(result.evidenceRefs, isEmpty);
      expect(result.confidence, equals(0.9));
      expect(result.asOf, equals(asOf));
      expect(result.metadata, equals(metadata));
      expect(result.actions, isNull);
      expect(result.rubricScores, isNull);
      expect(result.conflicts, isNull);
      expect(result.policyVersion, isNull);
      expect(result.ui, isNull);
      expect(result.artifacts, isNull);
    });

    test('success factory creates success result', () {
      final metadata = createMetadata();
      const claim = Claim(
        id: 'claim-1',
        workspaceId: 'test-workspace',
        type: ClaimType.conclusion,
        text: 'Success',
        evidenceRefs: [],
        confidence: 0.95,
      );

      final result = SkillResult.success(
        claims: [claim],
        evidenceRefs: ['ref-1'],
        metadata: metadata,
        confidence: 0.95,
      );

      expect(result.claims, hasLength(1));
      expect(result.evidenceRefs, equals(['ref-1']));
      expect(result.confidence, equals(0.95));
      expect(result.isSuccess, isTrue);
    });

    test('error factory creates error result', () {
      final metadata = createMetadata();

      final result = SkillResult.error(
        error: 'Something went wrong',
        metadata: metadata,
      );

      expect(result.claims, hasLength(1));
      expect(result.claims.first.type, equals(ClaimType.conclusion));
      expect(result.claims.first.text, equals('Something went wrong'));
      expect(result.confidence, equals(0.0));
      expect(result.isSuccess, isFalse);
    });

    test('fromJson creates instance from JSON', () {
      final json = {
        'claims': [
          {
            'id': 'claim-1',
            'type': 'fact',
            'text': 'Test claim',
            'evidenceRefs': [],
            'confidence': 0.9,
          }
        ],
        'evidenceRefs': ['ref-1'],
        'confidence': 0.85,
        'asOf': '2024-01-15T10:00:00.000',
        'policyVersion': 'v1.0',
        'metadata': {
          'skillId': 'skill-1',
          'skillVersion': '1.0.0',
          'procedureId': 'proc-1',
          'startedAt': '2024-01-15T10:00:00.000',
          'finishedAt': '2024-01-15T10:01:00.000',
          'durationMs': 60000,
          'stepsExecuted': 3,
          'toolsCalled': [],
        },
      };

      final result = SkillResult.fromJson(json);

      expect(result.claims, hasLength(1));
      expect(result.evidenceRefs, equals(['ref-1']));
      expect(result.confidence, equals(0.85));
      expect(result.policyVersion, equals('v1.0'));
    });

    test('fromJson parses actions', () {
      final json = {
        'claims': <Map<String, dynamic>>[],
        'evidenceRefs': <String>[],
        'confidence': 0.9,
        'asOf': '2024-01-15T10:00:00.000',
        'actions': [
          {
            'type': 'execute',
            'description': 'Run test',
            'status': 'pending',
          }
        ],
        'metadata': {
          'skillId': 'skill-1',
          'skillVersion': '1.0.0',
          'procedureId': 'proc-1',
          'startedAt': '2024-01-15T10:00:00.000',
          'finishedAt': '2024-01-15T10:01:00.000',
          'durationMs': 60000,
          'stepsExecuted': 1,
          'toolsCalled': [],
        },
      };

      final result = SkillResult.fromJson(json);

      expect(result.actions, hasLength(1));
      expect(result.actions!.first.type, equals('execute'));
    });

    test('fromJson parses rubricScores', () {
      final json = {
        'claims': <Map<String, dynamic>>[],
        'evidenceRefs': <String>[],
        'confidence': 0.9,
        'asOf': '2024-01-15T10:00:00.000',
        'rubricScores': [
          {
            'rubricId': 'rubric-1',
            'dimensionScores': {'quality': 0.9},
            'totalScore': 90.0,
            'grade': 'A',
          }
        ],
        'metadata': {
          'skillId': 'skill-1',
          'skillVersion': '1.0.0',
          'procedureId': 'proc-1',
          'startedAt': '2024-01-15T10:00:00.000',
          'finishedAt': '2024-01-15T10:01:00.000',
          'durationMs': 60000,
          'stepsExecuted': 1,
          'toolsCalled': [],
        },
      };

      final result = SkillResult.fromJson(json);

      expect(result.rubricScores, hasLength(1));
      expect(result.rubricScores!.first.totalScore, equals(90.0));
    });

    test('fromJson parses conflicts', () {
      final json = {
        'claims': <Map<String, dynamic>>[],
        'evidenceRefs': <String>[],
        'confidence': 0.9,
        'asOf': '2024-01-15T10:00:00.000',
        'conflicts': [
          {
            'id': 'conflict-1',
            'type': 'contradiction',
            'description': 'Conflicting data',
            'claimIds': ['claim-1'],
            'severity': 'high',
          }
        ],
        'metadata': {
          'skillId': 'skill-1',
          'skillVersion': '1.0.0',
          'procedureId': 'proc-1',
          'startedAt': '2024-01-15T10:00:00.000',
          'finishedAt': '2024-01-15T10:01:00.000',
          'durationMs': 60000,
          'stepsExecuted': 1,
          'toolsCalled': [],
        },
      };

      final result = SkillResult.fromJson(json);

      expect(result.conflicts, hasLength(1));
      expect(result.conflicts!.first.severity, equals('high'));
    });

    test('fromJson parses artifacts', () {
      final json = {
        'claims': <Map<String, dynamic>>[],
        'evidenceRefs': <String>[],
        'confidence': 0.9,
        'asOf': '2024-01-15T10:00:00.000',
        'artifacts': [
          {
            'id': 'artifact-1',
            'type': 'document',
            'content': 'content',
          }
        ],
        'metadata': {
          'skillId': 'skill-1',
          'skillVersion': '1.0.0',
          'procedureId': 'proc-1',
          'startedAt': '2024-01-15T10:00:00.000',
          'finishedAt': '2024-01-15T10:01:00.000',
          'durationMs': 60000,
          'stepsExecuted': 1,
          'toolsCalled': [],
        },
      };

      final result = SkillResult.fromJson(json);

      expect(result.artifacts, hasLength(1));
      expect(result.artifacts!.first.type, equals('document'));
    });

    test('toJson converts instance to JSON', () {
      final metadata = createMetadata();
      const claim = Claim(
        id: 'claim-1',
        workspaceId: 'test-workspace',
        type: ClaimType.fact,
        text: 'Test',
        evidenceRefs: [],
        confidence: 0.9,
      );
      final asOf = DateTime(2024, 1, 15);
      final result = SkillResult(
        claims: [claim],
        evidenceRefs: ['ref-1'],
        confidence: 0.85,
        asOf: asOf,
        policyVersion: 'v1.0',
        ui: {'screen': 'main'},
        metadata: metadata,
      );

      final json = result.toJson();

      expect(json['claims'], isA<List>());
      expect(json['evidenceRefs'], equals(['ref-1']));
      expect(json['confidence'], equals(0.85));
      expect(json['asOf'], equals(asOf.toIso8601String()));
      expect(json['policyVersion'], equals('v1.0'));
      expect(json['ui'], equals({'screen': 'main'}));
      expect(json['metadata'], isA<Map>());
    });

    test('isSuccess returns true when confidence > 0', () {
      final metadata = createMetadata();
      final result = SkillResult(
        claims: const [],
        evidenceRefs: const [],
        confidence: 0.1,
        asOf: DateTime.now(),
        metadata: metadata,
      );

      expect(result.isSuccess, isTrue);
    });

    test('isSuccess returns false when confidence is 0', () {
      final metadata = createMetadata();
      final result = SkillResult(
        claims: const [],
        evidenceRefs: const [],
        confidence: 0.0,
        asOf: DateTime.now(),
        metadata: metadata,
      );

      expect(result.isSuccess, isFalse);
    });

    test('primaryClaimText returns first claim text', () {
      final metadata = createMetadata();
      const claim = Claim(
        id: 'claim-1',
        workspaceId: 'test-workspace',
        type: ClaimType.fact,
        text: 'First claim',
        evidenceRefs: [],
        confidence: 0.9,
      );
      final result = SkillResult(
        claims: [claim],
        evidenceRefs: const [],
        confidence: 0.9,
        asOf: DateTime.now(),
        metadata: metadata,
      );

      expect(result.primaryClaimText, equals('First claim'));
    });

    test('primaryClaimText returns null when no claims', () {
      final metadata = createMetadata();
      final result = SkillResult(
        claims: const [],
        evidenceRefs: const [],
        confidence: 0.9,
        asOf: DateTime.now(),
        metadata: metadata,
      );

      expect(result.primaryClaimText, isNull);
    });

    test('toString returns expected string representation', () {
      final metadata = createMetadata();
      const claim = Claim(
        id: 'claim-1',
        workspaceId: 'test-workspace',
        type: ClaimType.fact,
        text: 'Test',
        evidenceRefs: [],
        confidence: 0.9,
      );
      final result = SkillResult(
        claims: [claim],
        evidenceRefs: ['ref-1', 'ref-2'],
        confidence: 0.85,
        asOf: DateTime.now(),
        metadata: metadata,
      );

      final str = result.toString();

      expect(str, contains('SkillResult'));
      expect(str, contains('1'));
      expect(str, contains('0.85'));
      expect(str, contains('2'));
    });
  });
}
