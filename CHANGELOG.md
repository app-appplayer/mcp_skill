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
