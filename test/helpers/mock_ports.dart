/// Mock port implementations for testing.
///
/// Simple class-based mocks that return configurable values. Used across
/// the `mcp_skill` test suite. Each mock matches the current (post
/// REDESIGN-PLAN Phase 3/4) capability-named port contract in
/// `mcp_bundle`.
library;

import 'package:mcp_bundle/mcp_bundle.dart' hide ContextBundleRequest, ContextBudget;
import 'package:mcp_bundle/src/ports/context_bundle_port.dart'
    show ContextBundleRequest;
import 'package:mcp_bundle/src/types/knowledge_types.dart' as knowledge;

// ============================================================================
// MockLlmPort
// ============================================================================

/// Mock LLM port with configurable responses.
class MockLlmPort extends LlmPort {
  /// Response to return from [complete].
  LlmResponse nextResponse;

  /// Embedding vector to return from [embed].
  List<double> nextEmbedding;

  /// Capabilities to report.
  @override
  final LlmCapabilities capabilities;

  /// Track calls made.
  final List<LlmRequest> completeCalls = [];
  final List<String> embedCalls = [];

  /// Optional error to throw on next call.
  Object? nextError;

  MockLlmPort({
    LlmResponse? response,
    List<double>? embedding,
    LlmCapabilities? capabilities,
  })  : nextResponse = response ??
            const LlmResponse(
              content: 'mock response',
              usage: LlmUsage(inputTokens: 10, outputTokens: 20),
            ),
        nextEmbedding = embedding ?? List.filled(384, 0.1),
        capabilities = capabilities ?? const LlmCapabilities.full();

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    completeCalls.add(request);
    if (nextError != null) {
      throw nextError!;
    }
    return nextResponse;
  }

  @override
  Future<List<double>> embed(String text) async {
    embedCalls.add(text);
    if (nextError != null) {
      throw nextError!;
    }
    return nextEmbedding;
  }

  /// Reset all tracked calls.
  void reset() {
    completeCalls.clear();
    embedCalls.clear();
    nextError = null;
  }
}

// ============================================================================
// MockMcpPort
// ============================================================================

/// Mock MCP port matching the unified `mcp_bundle.McpPort` contract.
class MockMcpPort implements McpPort {
  /// Tool result to return from [callTool].
  ToolResult nextToolResult;

  /// Resource content to return from [readResource].
  ResourceContent nextResourceContent;

  /// Tools to return from [listTools].
  List<ToolInfo> availableTools;

  /// Resources to return from [listResources].
  List<ResourceInfo> availableResources;

  /// Connectivity flag returned from [isConnected].
  bool connected;

  /// Track calls made.
  final List<_ToolCall> toolCalls = [];
  final List<String> resourceReads = [];

  /// Optional error to throw on next call.
  Object? nextError;

  MockMcpPort({
    ToolResult? toolResult,
    ResourceContent? resourceContent,
    List<ToolInfo>? tools,
    List<ResourceInfo>? resources,
    this.connected = true,
  })  : nextToolResult = toolResult ?? ToolResult.success('mock result'),
        nextResourceContent = resourceContent ??
            const ResourceContent(
              uri: 'mock://resource',
              mimeType: 'text/plain',
              text: 'mock content',
            ),
        availableTools = tools ?? const [],
        availableResources = resources ?? const [];

  @override
  Future<ToolResult> callTool(
    String name,
    Map<String, dynamic> arguments, {
    String? serverId,
  }) async {
    toolCalls.add(_ToolCall(name, arguments, serverId));
    if (nextError != null) {
      throw nextError!;
    }
    return nextToolResult;
  }

  @override
  Future<ResourceContent> readResource(
    String uri, {
    String? serverId,
  }) async {
    resourceReads.add(uri);
    if (nextError != null) {
      throw nextError!;
    }
    return nextResourceContent;
  }

  @override
  Future<List<ToolInfo>> listTools({String? serverId}) async => availableTools;

  @override
  Future<List<ResourceInfo>> listResources({String? serverId}) async =>
      availableResources;

  @override
  Stream<ResourceContent>? subscribeResource(
    String uri, {
    String? serverId,
  }) =>
      null;

  @override
  Future<PromptTemplate?> getPrompt(
    String name, {
    String? serverId,
    Map<String, dynamic>? arguments,
  }) async =>
      null;

  @override
  Future<bool> isConnected({String? serverId}) async => connected;

  /// Reset all tracked calls.
  void reset() {
    toolCalls.clear();
    resourceReads.clear();
    nextError = null;
  }
}

/// Record of a tool call for assertion.
class _ToolCall {
  final String toolName;
  final Map<String, dynamic> arguments;
  final String? serverId;
  _ToolCall(this.toolName, this.arguments, this.serverId);
}

// ============================================================================
// MockFactsPort
// ============================================================================

class MockFactsPort implements FactsPort {
  final List<FactRecord> storage = [];
  final List<FactQuery> queryCalls = [];

  @override
  Future<List<FactRecord>> queryFacts(FactQuery query) async {
    queryCalls.add(query);
    return List.unmodifiable(storage);
  }

  @override
  Future<void> writeFacts(List<FactRecord> facts) async {
    storage.addAll(facts);
  }

  @override
  Future<FactRecord?> getFact(String id) async {
    for (final f in storage) {
      if (f.id == id) return f;
    }
    return null;
  }

  @override
  Future<void> deleteFacts(List<String> ids) async {
    storage.removeWhere((f) => ids.contains(f.id));
  }
}

// ============================================================================
// MockClaimsPort
// ============================================================================

class MockClaimsPort implements ClaimsPort {
  /// Recorded writeClaims invocations as (claims, evidenceRefs) pairs.
  final List<(List<Claim>, List<String>)> writtenClaims = [];
  final List<ClaimQuery> queryCalls = [];
  ClaimValidationReport nextValidationReport =
      const ClaimValidationReport(passed: true, entries: []);

  @override
  Future<void> writeClaims(
    List<Claim> claims, {
    List<String>? evidenceRefs,
  }) async {
    writtenClaims.add((claims, evidenceRefs ?? const []));
  }

  @override
  Future<List<Claim>> queryClaims(ClaimQuery query) async {
    queryCalls.add(query);
    return const [];
  }

  @override
  Future<ClaimValidationReport> validateClaims(
    List<Claim> claims, {
    DateTime? asOf,
    String? policyVersion,
  }) async {
    return nextValidationReport;
  }

  @override
  Future<Claim?> getClaim(String id) async => null;

  @override
  Future<void> updateClaimStatus(String id, ClaimStatus status) async {}
}

// ============================================================================
// MockRunsPort
// ============================================================================

class MockRunsPort implements RunsPort {
  /// Recorded run records in insertion order.
  final List<RunRecord> writtenRuns = [];

  /// Optional error thrown by [writeRun].
  Object? writeError;

  @override
  Future<void> writeRun(RunRecord record) async {
    if (writeError != null) throw writeError!;
    writtenRuns.add(record);
  }

  @override
  Future<List<RunRecord>> queryRuns(RunQuery query) async {
    return List.unmodifiable(writtenRuns);
  }

  @override
  Future<RunRecord?> getRun(String id) async {
    for (final r in writtenRuns) {
      if (r.id == id) return r;
    }
    return null;
  }
}

// ============================================================================
// MockContextBundlePort
// ============================================================================

class MockContextBundlePort implements ContextBundlePort {
  ContextBundle? nextBundle;
  final List<ContextBundleRequest> buildCalls = [];

  @override
  Future<ContextBundle> buildContextBundle(
    ContextBundleRequest request,
  ) async {
    buildCalls.add(request);
    return nextBundle ??
        ContextBundle(
          id: 'mock-${request.workspaceId}',
          createdAt: request.asOf ?? DateTime.now(),
        );
  }
}

// ============================================================================
// MockRetrievalPort
// ============================================================================

class MockRetrievalPort implements RetrievalPort {
  RetrievalResult nextQueryResult = const RetrievalResult(passages: []);
  final List<String> queryCalls = [];
  Object? nextError;

  @override
  Future<RetrievalResult> queryKnowledge(
    String query, {
    String? retrieverId,
    Map<String, dynamic>? filters,
    int? maxResults,
  }) async {
    queryCalls.add(query);
    if (nextError != null) throw nextError!;
    return nextQueryResult;
  }

  @override
  Future<List<RetrieverInfo>> listRetrievers() async => const [];

  void reset() {
    queryCalls.clear();
    nextError = null;
  }
}

// ============================================================================
// MockAssetPort
// ============================================================================

class MockAssetPort implements AssetPort {
  final Map<String, AssetContent> assets = {};

  @override
  Future<AssetContent> getAsset(String id) async {
    final asset = assets[id];
    if (asset == null) {
      throw knowledge.AssetNotFoundException(id);
    }
    return asset;
  }

  @override
  Stream<List<int>> streamAsset(String id) async* {
    final asset = assets[id];
    if (asset == null) {
      throw knowledge.AssetNotFoundException(id);
    }
    yield asset.asBytes ?? const [];
  }
}
