/// Skill Ports Container - Container for all port implementations.
///
/// Provides a unified container for all ports required by skill execution.
library;

import 'llm_port.dart';
import 'mcp_port.dart';
import 'knowledge_port.dart';
import 'fact_graph_port.dart';

/// Container for all port implementations.
class SkillPorts {
  /// LLM port for LLM interactions.
  final LlmPort llm;

  /// MCP port for MCP tool/resource access.
  final McpPort mcp;

  /// Knowledge port for RAG operations.
  final KnowledgePort knowledge;

  /// FactGraph port for graph operations (optional).
  final FactGraphPort? factGraph;

  const SkillPorts({
    required this.llm,
    required this.mcp,
    required this.knowledge,
    this.factGraph,
  });

  /// Create with stub implementations.
  factory SkillPorts.stub() {
    return const SkillPorts(
      llm: StubLlmPort(),
      mcp: StubMcpPort(),
      knowledge: EmptyKnowledgePort(),
      factGraph: null,
    );
  }

  /// Create a copy with some ports replaced.
  SkillPorts copyWith({
    LlmPort? llm,
    McpPort? mcp,
    KnowledgePort? knowledge,
    FactGraphPort? factGraph,
  }) {
    return SkillPorts(
      llm: llm ?? this.llm,
      mcp: mcp ?? this.mcp,
      knowledge: knowledge ?? this.knowledge,
      factGraph: factGraph ?? this.factGraph,
    );
  }
}
