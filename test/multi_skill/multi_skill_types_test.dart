import 'package:test/test.dart';
import 'package:mcp_skill/src/multi_skill/multi_skill_types.dart';

void main() {
  group('MultiSkillConfig', () {
    test('constructor sets all fields', () {
      const config = MultiSkillConfig(
        mode: MultiSkillMode.chain,
        skills: [SkillRef(skillId: 'skill-1')],
        chainConfig: ChainConfig(stopOnFailure: false),
        timeout: Duration(seconds: 30),
        errorStrategy: MultiSkillErrorStrategy.continueOnError,
      );
      expect(config.mode, MultiSkillMode.chain);
      expect(config.skills.length, 1);
      expect(config.chainConfig, isNotNull);
      expect(config.competitionConfig, isNull);
      expect(config.parallelConfig, isNull);
      expect(config.timeout, const Duration(seconds: 30));
      expect(config.errorStrategy, MultiSkillErrorStrategy.continueOnError);
    });

    test('errorStrategy defaults to failFast', () {
      const config = MultiSkillConfig(
        mode: MultiSkillMode.parallel,
        skills: [],
      );
      expect(config.errorStrategy, MultiSkillErrorStrategy.failFast);
    });
  });

  group('MultiSkillMode', () {
    test('has all expected values', () {
      expect(MultiSkillMode.values, hasLength(3));
      expect(MultiSkillMode.values, contains(MultiSkillMode.chain));
      expect(MultiSkillMode.values, contains(MultiSkillMode.competition));
      expect(MultiSkillMode.values, contains(MultiSkillMode.parallel));
    });
  });

  group('SkillRef', () {
    test('constructor sets fields', () {
      const ref = SkillRef(
        skillId: 'skill-A',
        version: '2.0.0',
        inputOverrides: {'key': 'val'},
        condition: 'inputs.type == "special"',
      );
      expect(ref.skillId, 'skill-A');
      expect(ref.version, '2.0.0');
      expect(ref.inputOverrides, {'key': 'val'});
      expect(ref.condition, 'inputs.type == "special"');
    });

    test('fromJson creates correct instance', () {
      final ref = SkillRef.fromJson({
        'skillId': 'skill-B',
        'version': '1.0.0',
        'inputOverrides': {'x': 1},
        'condition': 'true',
      });
      expect(ref.skillId, 'skill-B');
      expect(ref.version, '1.0.0');
      expect(ref.inputOverrides, {'x': 1});
      expect(ref.condition, 'true');
    });

    test('fromJson uses defaults for missing values', () {
      final ref = SkillRef.fromJson({});
      expect(ref.skillId, '');
      expect(ref.version, isNull);
      expect(ref.inputOverrides, isNull);
      expect(ref.condition, isNull);
    });
  });

  group('ChainConfig', () {
    test('default constructor', () {
      const config = ChainConfig();
      expect(config.outputMappings, isEmpty);
      expect(config.stopOnFailure, true);
    });

    test('custom values', () {
      const config = ChainConfig(
        outputMappings: [
          OutputMapping(source: 'result.text', target: 'input'),
        ],
        stopOnFailure: false,
      );
      expect(config.outputMappings.length, 1);
      expect(config.stopOnFailure, false);
    });
  });

  group('OutputMapping', () {
    test('constructor sets fields', () {
      const mapping = OutputMapping(
        source: 'output.summary',
        target: 'input.text',
        transform: 'lowercase()',
      );
      expect(mapping.source, 'output.summary');
      expect(mapping.target, 'input.text');
      expect(mapping.transform, 'lowercase()');
    });

    test('transform is optional', () {
      const mapping = OutputMapping(
        source: 's',
        target: 't',
      );
      expect(mapping.transform, isNull);
    });
  });

  group('CompetitionConfig', () {
    test('default constructor', () {
      const config = CompetitionConfig();
      expect(config.criteria, SelectionCriteria.highestConfidence);
      expect(config.scoringExpression, isNull);
      expect(config.rubricId, isNull);
    });

    test('custom values', () {
      const config = CompetitionConfig(
        criteria: SelectionCriteria.rubricScore,
        rubricId: 'rubric-1',
      );
      expect(config.criteria, SelectionCriteria.rubricScore);
      expect(config.rubricId, 'rubric-1');
    });
  });

  group('SelectionCriteria', () {
    test('has all expected values', () {
      expect(SelectionCriteria.values, hasLength(4));
      expect(SelectionCriteria.values, contains(SelectionCriteria.highestConfidence));
      expect(SelectionCriteria.values, contains(SelectionCriteria.mostEvidence));
      expect(SelectionCriteria.values, contains(SelectionCriteria.rubricScore));
      expect(SelectionCriteria.values, contains(SelectionCriteria.custom));
    });
  });

  group('ParallelConfig', () {
    test('default constructor', () {
      const config = ParallelConfig();
      expect(config.maxConcurrency, 5);
      expect(config.aggregation, AggregationStrategy.mergeClaims);
      expect(config.minSuccessRatio, 0.5);
    });

    test('custom values', () {
      const config = ParallelConfig(
        maxConcurrency: 10,
        aggregation: AggregationStrategy.weightedMerge,
        minSuccessRatio: 0.8,
      );
      expect(config.maxConcurrency, 10);
      expect(config.aggregation, AggregationStrategy.weightedMerge);
      expect(config.minSuccessRatio, 0.8);
    });
  });

  group('AggregationStrategy', () {
    test('has all expected values', () {
      expect(AggregationStrategy.values, hasLength(4));
      expect(AggregationStrategy.values, contains(AggregationStrategy.mergeClaims));
      expect(AggregationStrategy.values, contains(AggregationStrategy.unionEvidence));
      expect(AggregationStrategy.values, contains(AggregationStrategy.weightedMerge));
      expect(AggregationStrategy.values, contains(AggregationStrategy.custom));
    });
  });

  group('MultiSkillErrorStrategy', () {
    test('has all expected values', () {
      expect(MultiSkillErrorStrategy.values, hasLength(3));
      expect(MultiSkillErrorStrategy.values, contains(MultiSkillErrorStrategy.failFast));
      expect(MultiSkillErrorStrategy.values, contains(MultiSkillErrorStrategy.continueOnError));
      expect(MultiSkillErrorStrategy.values, contains(MultiSkillErrorStrategy.fallback));
    });
  });
}
