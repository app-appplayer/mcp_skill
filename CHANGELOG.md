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
  - `SkillLlmPort` for LLM integration
  - `SkillMcpPort` for MCP tool calls
  - `SkillKnowledgePort` for knowledge access

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
