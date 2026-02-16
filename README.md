# MCP Skill

## Support This Project

If you find this package useful, consider supporting ongoing development on PayPal.

[![Donate](https://www.paypalobjects.com/en_US/i/btn/btn_donate_LG.gif)](https://www.paypal.com/ncp/payment/F7G56QD9LSJ92)
Support makemind via [PayPal](https://www.paypal.com/ncp/payment/F7G56QD9LSJ92)

---

### MCP Knowledge Package Family

- [`mcp_bundle`](https://pub.dev/packages/mcp_bundle): Bundle schema, loader, validator, and expression language for MCP ecosystem.
- [`mcp_fact_graph`](https://pub.dev/packages/mcp_fact_graph): Temporal knowledge graph with evidence-based fact management and summarization.
- [`mcp_skill`](https://pub.dev/packages/mcp_skill): Skill definitions and runtime execution for AI capabilities.
- [`mcp_profile`](https://pub.dev/packages/mcp_profile): Profile definitions for AI personas with template rendering and appraisal.
- [`mcp_knowledge_ops`](https://pub.dev/packages/mcp_knowledge_ops): Knowledge operations including pipelines, workflows, and scheduling.
- [`mcp_knowledge`](https://pub.dev/packages/mcp_knowledge): Unified integration package for the complete knowledge system.

---

A powerful Dart package for defining and executing AI skills with typed inputs/outputs, LLM integration, and claim recording. Part of the MakeMind MCP ecosystem.

## Features

### Core Features
- **Skill Definitions**: Type-safe skill definitions with JSON Schema validation
- **Runtime Execution**: Execute skills with full lifecycle management
- **LLM Integration**: Built-in support for LLM-powered skill execution
- **MCP Tool Bridge**: Seamless integration with MCP tools

### Skill Model
- **Input/Output Schemas**: JSON Schema-based type validation
- **Required vs Optional**: Clear input requirements specification
- **Metadata**: Tags, categories, and versioning support
- **Execution Context**: Full context during skill execution

### Advanced Features
- **Claim Recording**: Automatic claim generation from skill outputs
- **Port-Based Architecture**: Clean dependency injection via ports
- **Execution Tracking**: Full execution history and metrics
- **Timeout Handling**: Configurable execution timeouts

## Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  mcp_skill: ^0.1.0
```

### Basic Usage

```dart
import 'package:mcp_skill/mcp_skill.dart';

void main() async {
  // Create skill runtime with ports
  final runtime = SkillRuntime(
    storage: InMemorySkillStorage(),
    llm: MyLlmPort(),
    mcp: MyMcpPort(),
  );

  // Define a skill
  final skill = Skill(
    id: 'preference_extractor',
    name: 'Preference Extractor',
    description: 'Extracts user preferences from conversation',
    inputSchema: {
      'type': 'object',
      'properties': {
        'conversation': {'type': 'string'},
      },
      'required': ['conversation'],
    },
    outputSchema: {
      'type': 'object',
      'properties': {
        'preferences': {'type': 'array'},
      },
    },
    executor: SkillExecutorType.llm,
    llmPrompt: 'Extract user preferences from: {{conversation}}',
  );

  // Register skill
  await runtime.registerSkill(skill);

  // Execute skill
  final result = await runtime.execute(
    'preference_extractor',
    {'conversation': 'I prefer dark mode and large fonts'},
  );

  if (result.success) {
    print('Extracted: ${result.output}');
  }
}
```

## Core Concepts

### Skills

Skills represent executable AI capabilities:

```dart
final skill = Skill(
  id: 'summarizer',
  name: 'Text Summarizer',
  description: 'Summarizes text content',
  inputSchema: {
    'type': 'object',
    'properties': {
      'text': {'type': 'string'},
      'maxLength': {'type': 'integer'},
    },
    'required': ['text'],
  },
  outputSchema: {
    'type': 'object',
    'properties': {
      'summary': {'type': 'string'},
    },
  },
  executor: SkillExecutorType.llm,
  tags: ['nlp', 'summarization'],
  version: '1.0.0',
);
```

### Executor Types

Skills support multiple execution modes:

```dart
// LLM-powered execution
final llmSkill = Skill(
  executor: SkillExecutorType.llm,
  llmPrompt: 'Summarize: {{text}}',
  llmModel: 'claude-3-5-sonnet',
);

// MCP tool execution
final mcpSkill = Skill(
  executor: SkillExecutorType.mcp,
  mcpTool: 'calculator',
);

// Custom handler execution
final customSkill = Skill(
  executor: SkillExecutorType.handler,
  handlerId: 'my_custom_handler',
);
```

### Execution Results

Track execution outcomes with full context:

```dart
final result = await runtime.execute('summarizer', inputs);

print('Success: ${result.success}');
print('Output: ${result.output}');
print('Duration: ${result.duration}');
print('Execution ID: ${result.executionId}');

// Access any errors
if (!result.success) {
  print('Error: ${result.error}');
}
```

### Claim Recording

Skills can generate claims for the fact graph:

```dart
final result = await runtime.execute(
  'preference_extractor',
  inputs,
  recordClaims: true,
  entityId: 'user_123',
);

// Claims are automatically recorded
for (final claim in result.claims) {
  print('Claim: ${claim.domain} = ${claim.value}');
}
```

## Port-Based Architecture

The package uses a port-based dependency injection pattern:

```dart
// Define custom LLM port
class MyLlmPort implements SkillLlmPort {
  @override
  Future<String> complete(String prompt, {String? model}) async {
    // Your LLM implementation
  }
}

// Define custom MCP port
class MyMcpPort implements SkillMcpPort {
  @override
  Future<dynamic> callTool(String name, Map<String, dynamic> args) async {
    // Your MCP implementation
  }
}

// Inject custom ports
final runtime = SkillRuntime(
  storage: MySkillStorage(),
  llm: MyLlmPort(),
  mcp: MyMcpPort(),
);
```

## API Reference

### SkillRuntime

| Method | Description |
|--------|-------------|
| `registerSkill(skill)` | Register a skill definition |
| `execute(skillId, inputs)` | Execute a skill |
| `getSkill(skillId)` | Get skill definition |
| `listSkills(filter)` | List available skills |
| `unregisterSkill(skillId)` | Remove a skill |

### SkillExecutionResult

| Property | Description |
|----------|-------------|
| `success` | Whether execution succeeded |
| `output` | Skill output value |
| `error` | Error message if failed |
| `executionId` | Unique execution identifier |
| `duration` | Execution duration |
| `claims` | Generated claims |

## Examples

### Complete Examples Available
- `example/basic_skill.dart` - Basic skill definition and execution
- `example/llm_skill.dart` - LLM-powered skills
- `example/mcp_skill.dart` - MCP tool integration
- `example/claim_recording.dart` - Claim generation workflow

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## Support

- [Documentation](https://github.com/app-appplayer/mcp_skill/wiki)
- [Issue Tracker](https://github.com/app-appplayer/mcp_skill/issues)
- [Discussions](https://github.com/app-appplayer/mcp_skill/discussions)
- [Support on Patreon](https://www.patreon.com/mcpdevstudio)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
