/// Exceptions for port/adapter failures.
library;

import 'skill_exception.dart';

/// Base port exception.
class PortException extends SkillException {
  /// The port name that failed.
  final String portName;

  PortException(
    this.portName,
    String message, {
    Object? cause,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          code: 'PORT_ERROR',
          cause: cause,
          stackTrace: stackTrace,
        );
}

/// LLM port failure.
class LlmPortException extends PortException {
  /// HTTP status code (if applicable).
  final int? statusCode;

  LlmPortException(
    String message, {
    this.statusCode,
    Object? cause,
  }) : super('llm', message, cause: cause);

  @override
  String get code => 'LLM_PORT_ERROR';

  @override
  bool get isRetryable =>
      statusCode == null || statusCode! >= 500 || statusCode == 429;

  @override
  Duration? get retryDelay {
    if (statusCode == 429) return const Duration(seconds: 30);
    if (statusCode != null && statusCode! >= 500) {
      return const Duration(seconds: 5);
    }
    return const Duration(seconds: 1);
  }
}

/// MCP tool/resource port failure.
class McpPortException extends PortException {
  /// The tool name that failed (if applicable).
  final String? toolName;

  McpPortException(
    String message, {
    this.toolName,
    Object? cause,
  }) : super('mcp', message, cause: cause);

  @override
  String get code => 'MCP_PORT_ERROR';

  @override
  bool get isRetryable => true;

  @override
  Duration get retryDelay => const Duration(seconds: 2);
}

/// Knowledge port failure.
class KnowledgePortException extends PortException {
  /// The retriever that failed (if applicable).
  final String? retrieverId;

  KnowledgePortException(
    String message, {
    this.retrieverId,
    Object? cause,
  }) : super('knowledge', message, cause: cause);

  @override
  String get code => 'KNOWLEDGE_PORT_ERROR';

  @override
  bool get isRetryable => true;

  @override
  Duration get retryDelay => const Duration(seconds: 2);
}

/// FactGraph port failure.
class FactGraphPortException extends PortException {
  FactGraphPortException(
    String message, {
    Object? cause,
  }) : super('factGraph', message, cause: cause);

  @override
  String get code => 'FACTGRAPH_PORT_ERROR';

  @override
  bool get isRetryable => true;

  @override
  Duration get retryDelay => const Duration(seconds: 1);
}

/// Asset not found in knowledge port.
class AssetNotFoundException extends KnowledgePortException {
  /// The asset ID that was not found.
  final String assetId;

  AssetNotFoundException(this.assetId)
      : super('Asset not found: $assetId');

  @override
  String get code => 'ASSET_NOT_FOUND';

  @override
  bool get isRetryable => false;
}

/// Retriever not found in knowledge port.
class RetrieverNotFoundException extends KnowledgePortException {
  RetrieverNotFoundException(String retrieverId)
      : super('Retriever not found: $retrieverId', retrieverId: retrieverId);

  @override
  String get code => 'RETRIEVER_NOT_FOUND';

  @override
  bool get isRetryable => false;
}
