# MCP Skill

> **Positioning:** `mcp_skill` is an internal component of the MakeMind knowledge stack exposed through the `mcp_knowledge` facade. Application code should import `package:mcp_knowledge/mcp_knowledge.dart` — the symbols declared here are re-exported from there. Direct `package:mcp_skill/` imports remain valid for advanced or integration scenarios but are discouraged in product code.

A typed skill definition and execution runtime for AI capabilities — JSON-Schema-validated inputs/outputs, multi-step procedures with branching and circuit breakers, embedded expression language, and Contract Layer integration with the rest of the MCP ecosystem.

## Components

- **Definition** — `Skill`, `Parameter`, `Step`, `Procedure` models.
- **Bundle** — `SkillBundle` packaging with loader, validator, capability composition, capability verifier, permission enforcer.
- **Module conversion** — `skillBundleFromModule` turns a bundle skill module into a runnable skill bundle and refuses, with the procedure and step named, any shape the runtime does not execute. Step types: `prompt`, `tool`, `retrieve`, `validate`, `transform`, `branch`, `loop` (bounded) and `output`.
- **Registry** — `SkillRegistry` and an in-memory implementation.
- **Runtime** — `SkillRuntime` with context builder, branch merger, circuit breaker, error aggregator, claim extractor, procedure executor.
- **Multi-skill** — chained execution and dependency resolution across skills.
- **Expression language** — lexer / parser / AST / evaluator / function registry for skill conditionals and templated values.
- **Evaluation** — rubric-based scoring of skill executions.
- **FactGraph integration** — bridge into `mcp_fact_graph` for claim recording.
- **Contract Layer adapters** — `SkillRuntimePortAdapter`, `SkillRegistryPortAdapter` implementing the `mcp_bundle` standard ports.

## Quick Start

```dart
import 'package:mcp_skill/mcp_skill.dart';

final registry = MemorySkillRegistry();
await registry.register(mySkill);

final runtime = SkillRuntime(registry: registry, llm: llmPort);
final result = await runtime.run(skillId: 'summarize', input: {'text': '...'});
```

## Support

- [Issue Tracker](https://github.com/app-appplayer/mcp_skill/issues)
- [Discussions](https://github.com/app-appplayer/mcp_skill/discussions)

## License

MIT — see [LICENSE](LICENSE).
