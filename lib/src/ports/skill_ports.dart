/// Skill Ports container — composition root for skill execution.
///
/// Per REDESIGN-PLAN §3.4, `SkillPorts` now aggregates capability-named
/// standard ports defined in `mcp_bundle` instead of the monolithic
/// `SkillFactGraphPort`. `LlmPort` and `McpPort` are required; all
/// fact-graph-backed capabilities are optional so that scenario B
/// (Skill + LLM + MCP only) remains composable without RAG.
library;

import 'package:mcp_bundle/mcp_bundle.dart'
    show
        LlmPort,
        StubLlmPort,
        McpPort,
        StubMcpPort,
        FactsPort,
        StubFactsPort,
        ClaimsPort,
        StubClaimsPort,
        RunsPort,
        StubRunsPort,
        ContextBundlePort,
        StubContextBundlePort,
        RetrievalPort,
        StubRetrievalPort,
        AssetPort,
        StubAssetPort;

export 'package:mcp_bundle/mcp_bundle.dart'
    show
        LlmPort,
        StubLlmPort,
        McpPort,
        StubMcpPort,
        FactsPort,
        StubFactsPort,
        ClaimsPort,
        StubClaimsPort,
        RunsPort,
        StubRunsPort,
        ContextBundlePort,
        StubContextBundlePort,
        RetrievalPort,
        StubRetrievalPort,
        AssetPort,
        StubAssetPort;

/// Container for the ports required by `SkillRuntime` and friends.
///
/// `llm` and `mcp` are the minimum required capabilities. The remaining
/// ports are optional so hosts can construct a runtime with only the
/// capabilities they need. See REDESIGN-PLAN §3.4 Open Question 7 for
/// the rationale behind the flat (versus composite) shape.
class SkillPorts {
  /// LLM invocation port (required).
  final LlmPort llm;

  /// MCP tool/resource port (required).
  final McpPort mcp;

  /// Facts CRUD port (optional).
  final FactsPort? facts;

  /// Claims CRUD and validation port (optional).
  final ClaimsPort? claims;

  /// Run record persistence port (optional).
  final RunsPort? runs;

  /// Context bundle assembly port (optional).
  final ContextBundlePort? contextBundle;

  /// Knowledge retrieval (RAG) port (optional).
  final RetrievalPort? retrieval;

  /// Binary asset retrieval port (optional).
  final AssetPort? asset;

  const SkillPorts({
    required this.llm,
    required this.mcp,
    this.facts,
    this.claims,
    this.runs,
    this.contextBundle,
    this.retrieval,
    this.asset,
  });

  /// Test-only stub factory that wires every port to its in-memory stub.
  factory SkillPorts.stub() {
    return SkillPorts(
      llm: StubLlmPort(),
      mcp: const StubMcpPort(),
      facts: const StubFactsPort(),
      claims: const StubClaimsPort(),
      runs: const StubRunsPort(),
      contextBundle: const StubContextBundlePort(),
      retrieval: const StubRetrievalPort(),
      asset: const StubAssetPort(),
    );
  }

  /// Return a copy with the supplied fields replaced.
  SkillPorts copyWith({
    LlmPort? llm,
    McpPort? mcp,
    FactsPort? facts,
    ClaimsPort? claims,
    RunsPort? runs,
    ContextBundlePort? contextBundle,
    RetrievalPort? retrieval,
    AssetPort? asset,
  }) {
    return SkillPorts(
      llm: llm ?? this.llm,
      mcp: mcp ?? this.mcp,
      facts: facts ?? this.facts,
      claims: claims ?? this.claims,
      runs: runs ?? this.runs,
      contextBundle: contextBundle ?? this.contextBundle,
      retrieval: retrieval ?? this.retrieval,
      asset: asset ?? this.asset,
    );
  }
}
