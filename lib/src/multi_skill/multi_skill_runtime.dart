/// Multi-Skill Runtime - Dispatches to appropriate executor based on mode.
library;

import '../runtime/skill_context.dart';
import '../registry/skill_registry.dart';
import '../ports/skill_ports.dart';
import 'multi_skill_types.dart';
import 'multi_skill_result.dart';
import 'chain_executor.dart';
import 'competition_executor.dart';
import 'parallel_executor.dart';

/// Unified runtime for multi-skill execution.
///
/// Dispatches to the appropriate executor based on [MultiSkillMode].
class MultiSkillRuntime {
  final ChainExecutor _chainExecutor;
  final CompetitionExecutor _competitionExecutor;
  final ParallelExecutor _parallelExecutor;

  MultiSkillRuntime({
    required SkillBundleRegistry registry,
    required SkillPorts ports,
  })  : _chainExecutor = ChainExecutor(registry: registry, ports: ports),
        _competitionExecutor =
            CompetitionExecutor(registry: registry, ports: ports),
        _parallelExecutor =
            ParallelExecutor(registry: registry, ports: ports);

  /// Execute multiple skills according to the configuration.
  Future<MultiSkillResult> execute(
    MultiSkillConfig config,
    SkillContext context,
  ) async {
    // Apply timeout if configured
    if (config.timeout != null) {
      return await Future.any([
        _dispatch(config, context),
        Future.delayed(config.timeout!, () {
          throw TimeoutException(config.timeout!);
        }),
      ]);
    }

    return _dispatch(config, context);
  }

  Future<MultiSkillResult> _dispatch(
    MultiSkillConfig config,
    SkillContext context,
  ) async {
    return switch (config.mode) {
      MultiSkillMode.chain => await _chainExecutor.execute(config, context),
      MultiSkillMode.competition =>
        await _competitionExecutor.execute(config, context),
      MultiSkillMode.parallel =>
        await _parallelExecutor.execute(config, context),
    };
  }
}

/// Timeout exception for multi-skill execution.
class TimeoutException implements Exception {
  final Duration timeout;
  TimeoutException(this.timeout);

  @override
  String toString() =>
      'Multi-skill execution timed out after ${timeout.inMilliseconds}ms';
}
