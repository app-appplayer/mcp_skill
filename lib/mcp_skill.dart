/// MCP Skill - Skill definitions and execution for AI capabilities.
library mcp_skill;

// ============================================================================
// Definition Layer
// ============================================================================

export 'src/definition/skill.dart';
export 'src/definition/parameter.dart';
export 'src/definition/step.dart' hide RetryConfig;
export 'src/definition/procedure.dart';

// ============================================================================
// Executor (Legacy)
// ============================================================================

export 'src/executor/skill_executor.dart';
export 'src/executor/execution_context.dart';

// ============================================================================
// Bundle
// ============================================================================

export 'src/bundle/skill_bundle.dart' hide RubricDimension, BundleValidator;
export 'src/bundle/bundle_loader.dart';
export 'src/bundle/bundle_validator.dart';
export 'src/bundle/module_conversion.dart';
export 'src/bundle/capability_types.dart';
export 'src/bundle/capability_composer.dart';
export 'src/bundle/capability_verifier.dart';
export 'src/bundle/permission_enforcer.dart';

// ============================================================================
// Registry
// ============================================================================

export 'src/registry/skill_registry.dart';
export 'src/registry/memory_registry.dart';

// ============================================================================
// Ports
// ============================================================================

export 'src/ports/skill_port.dart';
export 'src/ports/llm_port.dart';
// Unified McpPort and capability-named fact-graph ports come from
// mcp_bundle (REDESIGN-PLAN Phase 3/4). The local `mcp_port.dart` and
// `fact_graph_port.dart` shims were deleted; consumers get the
// capability ports through `skill_ports.dart`.
export 'src/ports/skill_ports.dart';

// ============================================================================
// Adapters (Bundle Port Implementation)
// ============================================================================

export 'src/adapters/skill_runtime_port_adapter.dart';
export 'src/adapters/skill_registry_port_adapter.dart';

// ============================================================================
// Exceptions
// ============================================================================

export 'src/exceptions/exceptions.dart';

// ============================================================================
// Expression Language
// ============================================================================

export 'src/expression/ast.dart';
export 'src/expression/tokenizer.dart';
export 'src/expression/parser.dart';
export 'src/expression/evaluation_context.dart';
export 'src/expression/function_registry.dart';
export 'src/expression/expression_exception.dart';
export 'src/expression/skill_expression_evaluator.dart';

// ============================================================================
// Runtime
// ============================================================================

export 'src/runtime/skill_runtime.dart';
export 'src/runtime/skill_context.dart';
export 'src/runtime/skill_result.dart';
export 'src/runtime/procedure_executor.dart'
    hide Procedure, StepAction, QualityGate, QualityGateAction, QualityGateException;
export 'src/runtime/step_executor.dart' hide UnsupportedActionException;
export 'src/runtime/skill_router.dart';
export 'src/runtime/runtime_hooks.dart';
export 'src/runtime/claim_extractor.dart';
export 'src/runtime/profile_aware_runtime.dart';

// Runtime: Context infrastructure
export 'src/runtime/context_types.dart';
export 'src/runtime/context_builder.dart';
export 'src/runtime/expression_interpolator.dart';
export 'src/runtime/shared_budget_tracker.dart';
export 'src/runtime/retry_config.dart';

// Runtime: Error infrastructure
export 'src/runtime/retry_executor.dart';
export 'src/runtime/recovery_strategy.dart';
export 'src/runtime/error_aggregator.dart';
export 'src/runtime/circuit_breaker.dart';
export 'src/runtime/error_context.dart';

// Runtime: Parallel execution
export 'src/runtime/parallel_context.dart';
export 'src/runtime/branch_merger.dart';
export 'src/runtime/state_conflict_detector.dart';

// ============================================================================
// FactGraph Integration
// ============================================================================

export 'src/factgraph/persistence_types.dart';
export 'src/factgraph/skill_result_persistence.dart';
export 'src/factgraph/skill_result_retrieval.dart';

// ============================================================================
// Multi-Skill Execution
// ============================================================================

export 'src/multi_skill/multi_skill_types.dart';
export 'src/multi_skill/multi_skill_result.dart';
export 'src/multi_skill/multi_skill_runtime.dart';
export 'src/multi_skill/chain_executor.dart';
export 'src/multi_skill/competition_executor.dart';
export 'src/multi_skill/parallel_executor.dart';

// ============================================================================
// Evaluation
// ============================================================================

export 'src/evaluation/rubric.dart' hide ValidationResult;
export 'src/evaluation/rubric_engine.dart'
    hide RubricException, RubricValidationException, RubricNotFoundException, MissingMeasurementException;
export 'src/evaluation/measurement_extractor.dart' hide UnknownExtractorException;

// ============================================================================
// Dependency Resolution
// ============================================================================

export 'src/dependency/dependency.dart';
