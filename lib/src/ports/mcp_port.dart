/// MCP Port - Abstract interface for MCP server interactions.
///
/// Defines contracts for MCP tool and resource access in skill execution.
library;

/// Port for MCP server interactions.
abstract class McpPort {
  /// Call an MCP tool.
  Future<ToolResult> callTool(
    String toolName,
    Map<String, dynamic> arguments, {
    String? serverId,
  });

  /// Read an MCP resource.
  Future<ResourceContent> readResource(
    String uri, {
    String? serverId,
  });

  /// List available tools.
  Future<List<ToolInfo>> listTools({String? serverId});

  /// List available resources.
  Future<List<ResourceInfo>> listResources({String? serverId});

  /// Subscribe to resource updates.
  Stream<ResourceUpdate>? subscribeResource(String uri, {String? serverId}) =>
      null;

  /// Get prompt template.
  Future<PromptTemplate?> getPrompt(
    String promptName, {
    String? serverId,
    Map<String, String>? arguments,
  }) async =>
      null;
}

/// Tool call result.
class ToolResult {
  /// Result content.
  final dynamic content;

  /// Whether the call resulted in an error.
  final bool isError;

  /// Error message if failed.
  final String? errorMessage;

  /// Additional metadata.
  final Map<String, dynamic>? metadata;

  const ToolResult({
    required this.content,
    this.isError = false,
    this.errorMessage,
    this.metadata,
  });

  /// Create a success result.
  factory ToolResult.success(dynamic content, {Map<String, dynamic>? metadata}) {
    return ToolResult(
      content: content,
      isError: false,
      metadata: metadata,
    );
  }

  /// Create an error result.
  factory ToolResult.error(String message, {Map<String, dynamic>? metadata}) {
    return ToolResult(
      content: null,
      isError: true,
      errorMessage: message,
      metadata: metadata,
    );
  }

  factory ToolResult.fromJson(Map<String, dynamic> json) {
    return ToolResult(
      content: json['content'],
      isError: json['isError'] as bool? ?? false,
      errorMessage: json['errorMessage'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'content': content,
        'isError': isError,
        if (errorMessage != null) 'errorMessage': errorMessage,
        if (metadata != null) 'metadata': metadata,
      };
}

/// Resource content.
class ResourceContent {
  /// Resource URI.
  final String uri;

  /// MIME type.
  final String mimeType;

  /// Content (String or bytes).
  final dynamic content;

  /// Additional metadata.
  final Map<String, dynamic>? metadata;

  const ResourceContent({
    required this.uri,
    required this.mimeType,
    required this.content,
    this.metadata,
  });

  /// Get content as string.
  String? get asString => content is String ? content as String : null;

  /// Get content as bytes.
  List<int>? get asBytes => content is List<int> ? content as List<int> : null;

  factory ResourceContent.fromJson(Map<String, dynamic> json) {
    return ResourceContent(
      uri: json['uri'] as String,
      mimeType: json['mimeType'] as String,
      content: json['content'],
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'uri': uri,
        'mimeType': mimeType,
        'content': content,
        if (metadata != null) 'metadata': metadata,
      };
}

/// Tool information.
class ToolInfo {
  /// Tool name.
  final String name;

  /// Tool description.
  final String? description;

  /// Input schema as JSON Schema.
  final Map<String, dynamic> inputSchema;

  const ToolInfo({
    required this.name,
    this.description,
    required this.inputSchema,
  });

  factory ToolInfo.fromJson(Map<String, dynamic> json) {
    return ToolInfo(
      name: json['name'] as String,
      description: json['description'] as String?,
      inputSchema: json['inputSchema'] as Map<String, dynamic>,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null) 'description': description,
        'inputSchema': inputSchema,
      };
}

/// Resource information.
class ResourceInfo {
  /// Resource URI.
  final String uri;

  /// Resource name.
  final String name;

  /// Resource description.
  final String? description;

  /// MIME type.
  final String? mimeType;

  const ResourceInfo({
    required this.uri,
    required this.name,
    this.description,
    this.mimeType,
  });

  factory ResourceInfo.fromJson(Map<String, dynamic> json) {
    return ResourceInfo(
      uri: json['uri'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      mimeType: json['mimeType'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'uri': uri,
        'name': name,
        if (description != null) 'description': description,
        if (mimeType != null) 'mimeType': mimeType,
      };
}

/// Resource update notification.
class ResourceUpdate {
  /// Resource URI.
  final String uri;

  /// Update type.
  final ResourceUpdateType type;

  /// Updated content (if available).
  final ResourceContent? content;

  /// Update timestamp.
  final DateTime timestamp;

  const ResourceUpdate({
    required this.uri,
    required this.type,
    this.content,
    required this.timestamp,
  });

  factory ResourceUpdate.fromJson(Map<String, dynamic> json) {
    return ResourceUpdate(
      uri: json['uri'] as String,
      type: ResourceUpdateType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ResourceUpdateType.changed,
      ),
      content: json['content'] != null
          ? ResourceContent.fromJson(json['content'] as Map<String, dynamic>)
          : null,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'uri': uri,
        'type': type.name,
        if (content != null) 'content': content!.toJson(),
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Resource update types.
enum ResourceUpdateType {
  /// Resource content changed.
  changed,

  /// Resource was created.
  created,

  /// Resource was deleted.
  deleted,
}

/// Prompt template from MCP server.
class PromptTemplate {
  /// Prompt name.
  final String name;

  /// Prompt description.
  final String? description;

  /// Rendered messages.
  final List<PromptMessage> messages;

  const PromptTemplate({
    required this.name,
    this.description,
    required this.messages,
  });

  factory PromptTemplate.fromJson(Map<String, dynamic> json) {
    return PromptTemplate(
      name: json['name'] as String,
      description: json['description'] as String?,
      messages: (json['messages'] as List<dynamic>)
          .map((e) => PromptMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null) 'description': description,
        'messages': messages.map((m) => m.toJson()).toList(),
      };
}

/// Prompt message.
class PromptMessage {
  /// Message role.
  final String role;

  /// Message content.
  final String content;

  const PromptMessage({
    required this.role,
    required this.content,
  });

  factory PromptMessage.fromJson(Map<String, dynamic> json) {
    return PromptMessage(
      role: json['role'] as String,
      content: json['content'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
      };
}

/// Stub MCP port that throws on use.
class StubMcpPort implements McpPort {
  const StubMcpPort();

  @override
  Future<ToolResult> callTool(
    String toolName,
    Map<String, dynamic> arguments, {
    String? serverId,
  }) {
    throw UnimplementedError('McpPort not configured');
  }

  @override
  Future<ResourceContent> readResource(String uri, {String? serverId}) {
    throw UnimplementedError('McpPort not configured');
  }

  @override
  Future<List<ToolInfo>> listTools({String? serverId}) async => [];

  @override
  Future<List<ResourceInfo>> listResources({String? serverId}) async => [];

  @override
  Stream<ResourceUpdate>? subscribeResource(String uri, {String? serverId}) =>
      null;

  @override
  Future<PromptTemplate?> getPrompt(
    String promptName, {
    String? serverId,
    Map<String, String>? arguments,
  }) async =>
      null;
}
