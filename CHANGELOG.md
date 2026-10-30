## [0.3.0] - 2026-10-30 - Branch, loop and output steps, one conversion from bundle skills, tool errors fail the step

### Breaking
Under the 0.x compatibility rule these make this release a minor. Consumers on `^0.2.x` keep the old behaviour until they raise their floor.
- A `tool` step whose result has `isError: true` now fails the step (`ActionExecutionException`): `onFailure` takes over, or the procedure fails. It used to succeed with the error as its content.
- `condition` (and quality gate conditions) are evaluated. Without an injected evaluator every condition was assumed true, so guarded steps always ran. A condition that cannot be evaluated is not met; truthiness follows bundle spec 11 §11.8 (`0`, `""`, an empty list and an empty map are falsy).
- `onSuccess` / `onFailure` / `branch` targets that name an unknown step or an earlier step raise `InvalidProcedureException`. They used to skip the remaining steps without a word.
- `${...}` in step text is evaluated with the expression language (bundle spec 11 §11.7), not three fixed patterns; an expression that fails renders as the empty string. The interpolation itself is `mcp_bundle`'s `renderInterpolation` / `renderInterpolatedValue`, shared with the behavior engine.
- `transform` runs without an injected evaluator (it threw `UnsupportedActionException`).
- In `args` and `filters`, a string that is exactly one `${...}` takes the value of the expression with its type (it was always text), and templates inside lists are rendered (they were left as written).
- `runProcedure(skillId, procedureId, ...)` runs the procedure it is given; it used to run the first one whatever the id.

### Added
- Claim extraction can be switched off or narrowed: `SkillRuntime(claimExtraction: ClaimExtractionConfig(strategy: ClaimExtractionStrategy.none))` for a host that uses a reply as plain text (no claims and no extra LLM call), and `extractClaims` (`none`, `rules`, `llm`, `hybrid`) on a `prompt` / `llm` step for one step; the step wins. `ProcedureExecutor` and `StepExecutor` take the same `claimExtraction`. The default is unchanged (`hybrid`). `ClaimExtractionStrategy` gains `none`, which also makes an exhaustive `switch` over it incomplete.
- `SkillContext.procedureId`: a run names the procedure it wants; without one the first runs (it was always the first, and `runProcedure` ignored its `procedureId`). An unknown id is an error naming it.
- `parseJson` in the expression language (code fence removed, invalid text fails the evaluation), so a step can read a model's JSON reply: `parseJson(steps.judge.result).score >= 0.7`.
- `skillBundleFromModule(module, {id, provider})` and `procedureFromBundle(procedure)`: the one conversion from a bundle skill module to a runnable skill bundle. It carries `next[0]` as `onSuccess` and `onError` as `onFailure`, accepts the bundle spellings (`prompt` for the model step, `template` for its text, `tool` for a tool name) and refuses what the runtime does not execute with `InvalidProcedureException` naming the procedure and the step (unknown step type, several `next`, a `next` / `onError` / `goto` that is unknown or not later, an `entryPoint` that is not the first step, repeated or empty step ids, malformed `branch` / `loop`).
- Step types `branch` (`cases[{when, goto}]`, `default`), `loop` (`over` or `while`, `as`, `maxIterations`, nested `steps`; every iteration and nested step counts against the run budget; `ProcedureExecutor.loopLimit`, default 1000, caps any loop) and `output` (ends the procedure; the value is `SkillResult.output`). Bundle spec 03 §3.5.1.
- A built-in expression evaluator (`defaultExpressionEvaluator`) used when none is injected. The expression language reads `steps.<id>.result` (it returned null before) and, inside a loop, `loop.<as>` and `loop.index`.
- `StepAction` (runtime and definition layer) carries `cases`, `default`, `over`, `while`, `as`, `maxIterations`, `steps` and `value`; the definition layer would otherwise drop them before execution.
- `InvalidProcedureException`.

### Changed (dependency floor)
- `mcp_bundle` floor raised to `^0.4.12` (`SkillResult.output`).

### Fixed
- Ids built from the clock alone (claim and run ids) repeated when two records were made in the same tick, and a store replaced the earlier record without an error. They now come from one process-wide generator, `<prefix><sep><microseconds><sep><sequence>`; prefixes and separators are unchanged.

## [0.2.1] - 2026-05-23 - mcp_bundle 0.4.0 cascade

### Changed (cascade)
- `mcp_bundle` caret bumped from `^0.3.0` to `^0.4.0`. mcp_skill does not touch `UiSection.pages` directly, so this release is a caret-only cascade. Consumers should bump to `^0.2.1`.

## [0.2.0] - 2026-04-28 - Bundle Subsystem & Multi-Skill Runtime

### Added
- Bundle subsystem — `BundleLoader`, `BundleValidator`, capability types / composer / verifier, permission enforcer.
- Multi-skill execution — `Procedure` model with branching, branch merger, circuit breaker, error aggregator.
- Embedded expression language (lexer / parser / AST / evaluator / function registry) for skill conditionals and templated values.
- Evaluation subsystem (rubric-based scoring) and FactGraph integration for claim recording.
- Standard port adapters — `SkillRuntimePortAdapter`, `SkillRegistryPortAdapter` implementing `mcp_bundle` Contract Layer.
- In-memory `MemorySkillRegistry`.

### Changed
- Runtime restructured around `SkillRuntime` with context builder, procedure executor, claim extractor.
- New dependency: `mcp_bundle ^0.3.0`.

### Removed
- Legacy ports — `fact_graph_port`, `knowledge_port`, `mcp_port` shims (consumers receive capability ports through `skill_ports.dart` now).

---

## [0.1.1] - Bugfix

### Fixed
- Unified LLM Port types to use mcp_bundle Contract Layer exclusively
- Updated documentation to reflect Contract Layer architecture

---

## [0.1.0] - Initial Release

### Added

#### Core Features
- **Skill Definitions**
  - `Skill` model with input/output schemas
  - JSON Schema validation for inputs and outputs
  - Metadata support (tags, categories, version)
  - Multiple executor types (LLM, MCP, Handler)

- **Skill Runtime**
  - `SkillRuntime` as the main execution engine
  - Skill registration and discovery
  - Execution with full lifecycle management
  - Timeout handling and error recovery

- **Execution Results**
  - `SkillExecutionResult` with success/failure status
  - Output capture and validation
  - Execution metrics (duration, timestamps)
  - Error details and stack traces

- **Claim Recording**
  - Automatic claim generation from skill outputs
  - Entity association for fact graph integration
  - Confidence scoring for claims

- **Port-Based Architecture**
  - `SkillStoragePort` for skill persistence
  - `LlmPort` for LLM integration (from mcp_bundle Contract Layer)
  - `McpPort` for MCP tool calls
  - `KnowledgePort` for knowledge access

- **In-Memory Implementations**
  - Complete in-memory storage for testing
  - Stub implementations for all ports

### Executor Types
- `SkillExecutorType.llm` - LLM-powered execution
- `SkillExecutorType.mcp` - MCP tool execution
- `SkillExecutorType.handler` - Custom handler execution

### Data Models
- `Skill` - Skill definition with schemas
- `SkillExecution` - Execution context and state
- `SkillExecutionResult` - Execution outcome
- `SkillInfo` - Lightweight skill metadata

---

## Support and Contributing

- [Report Issues](https://github.com/app-appplayer/mcp_skill/issues)
- [Join Discussions](https://github.com/app-appplayer/mcp_skill/discussions)
- [Read Documentation](https://github.com/app-appplayer/mcp_skill/wiki)
- [Support Development](https://www.patreon.com/mcpdevstudio)
