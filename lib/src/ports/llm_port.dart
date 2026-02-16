/// LLM Port - Abstract interface for LLM interactions.
///
/// Defines contracts for LLM completion calls in skill execution.
library;

/// Port for LLM interactions.
abstract class LlmPort {
  /// Complete a chat request.
  Future<LlmResponse> complete(LlmRequest request);

  /// Stream completion (optional).
  Stream<LlmChunk>? completeStream(LlmRequest request) => null;

  /// Generate embeddings for text.
  Future<List<double>> embed(String text);
}

/// LLM request.
class LlmRequest {
  /// Messages in the conversation.
  final List<LlmMessage> messages;

  /// Model identifier.
  final String? model;

  /// Sampling temperature.
  final double? temperature;

  /// Maximum tokens to generate.
  final int? maxTokens;

  /// Tools available for the LLM.
  final List<LlmTool>? tools;

  /// System prompt.
  final String? systemPrompt;

  /// Additional metadata.
  final Map<String, dynamic>? metadata;

  const LlmRequest({
    required this.messages,
    this.model,
    this.temperature,
    this.maxTokens,
    this.tools,
    this.systemPrompt,
    this.metadata,
  });

  /// Create a simple request with a single user message.
  factory LlmRequest.simple(
    String prompt, {
    String? systemPrompt,
    int? maxTokens,
    double? temperature,
  }) {
    return LlmRequest(
      messages: [LlmMessage.user(prompt)],
      systemPrompt: systemPrompt,
      maxTokens: maxTokens,
      temperature: temperature,
    );
  }

  Map<String, dynamic> toJson() => {
        'messages': messages.map((m) => m.toJson()).toList(),
        if (model != null) 'model': model,
        if (temperature != null) 'temperature': temperature,
        if (maxTokens != null) 'maxTokens': maxTokens,
        if (tools != null) 'tools': tools!.map((t) => t.toJson()).toList(),
        if (systemPrompt != null) 'systemPrompt': systemPrompt,
        if (metadata != null) 'metadata': metadata,
      };
}

/// LLM message.
class LlmMessage {
  /// Message role: "user", "assistant", "system", "tool".
  final String role;

  /// Message content.
  final String content;

  /// Tool calls made by assistant.
  final List<LlmToolCall>? toolCalls;

  /// Tool call ID for tool responses.
  final String? toolCallId;

  const LlmMessage({
    required this.role,
    required this.content,
    this.toolCalls,
    this.toolCallId,
  });

  /// Create a user message.
  factory LlmMessage.user(String content) {
    return LlmMessage(role: 'user', content: content);
  }

  /// Create an assistant message.
  factory LlmMessage.assistant(String content, {List<LlmToolCall>? toolCalls}) {
    return LlmMessage(role: 'assistant', content: content, toolCalls: toolCalls);
  }

  /// Create a system message.
  factory LlmMessage.system(String content) {
    return LlmMessage(role: 'system', content: content);
  }

  /// Create a tool response message.
  factory LlmMessage.tool(String toolCallId, String content) {
    return LlmMessage(role: 'tool', content: content, toolCallId: toolCallId);
  }

  factory LlmMessage.fromJson(Map<String, dynamic> json) {
    return LlmMessage(
      role: json['role'] as String,
      content: json['content'] as String,
      toolCalls: (json['toolCalls'] as List<dynamic>?)
          ?.map((e) => LlmToolCall.fromJson(e as Map<String, dynamic>))
          .toList(),
      toolCallId: json['toolCallId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        if (toolCalls != null)
          'toolCalls': toolCalls!.map((t) => t.toJson()).toList(),
        if (toolCallId != null) 'toolCallId': toolCallId,
      };
}

/// LLM tool definition.
class LlmTool {
  /// Tool name.
  final String name;

  /// Tool description.
  final String description;

  /// Input schema as JSON Schema.
  final Map<String, dynamic> inputSchema;

  const LlmTool({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  factory LlmTool.fromJson(Map<String, dynamic> json) {
    return LlmTool(
      name: json['name'] as String,
      description: json['description'] as String,
      inputSchema: json['inputSchema'] as Map<String, dynamic>,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'inputSchema': inputSchema,
      };
}

/// LLM response.
class LlmResponse {
  /// Response content.
  final String content;

  /// Tool calls requested by the LLM.
  final List<LlmToolCall>? toolCalls;

  /// Stop reason.
  final String? stopReason;

  /// Token usage.
  final LlmUsage? usage;

  /// Additional metadata.
  final Map<String, dynamic>? metadata;

  const LlmResponse({
    required this.content,
    this.toolCalls,
    this.stopReason,
    this.usage,
    this.metadata,
  });

  /// Whether the response contains tool calls.
  bool get hasToolCalls => toolCalls != null && toolCalls!.isNotEmpty;

  factory LlmResponse.fromJson(Map<String, dynamic> json) {
    return LlmResponse(
      content: json['content'] as String,
      toolCalls: (json['toolCalls'] as List<dynamic>?)
          ?.map((e) => LlmToolCall.fromJson(e as Map<String, dynamic>))
          .toList(),
      stopReason: json['stopReason'] as String?,
      usage: json['usage'] != null
          ? LlmUsage.fromJson(json['usage'] as Map<String, dynamic>)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'content': content,
        if (toolCalls != null)
          'toolCalls': toolCalls!.map((t) => t.toJson()).toList(),
        if (stopReason != null) 'stopReason': stopReason,
        if (usage != null) 'usage': usage!.toJson(),
        if (metadata != null) 'metadata': metadata,
      };
}

/// Tool call from LLM.
class LlmToolCall {
  /// Unique identifier for this tool call.
  final String id;

  /// Tool name.
  final String name;

  /// Tool arguments.
  final Map<String, dynamic> arguments;

  const LlmToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  factory LlmToolCall.fromJson(Map<String, dynamic> json) {
    return LlmToolCall(
      id: json['id'] as String,
      name: json['name'] as String,
      arguments: json['arguments'] as Map<String, dynamic>,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'arguments': arguments,
      };
}

/// Token usage information.
class LlmUsage {
  /// Input tokens.
  final int inputTokens;

  /// Output tokens.
  final int outputTokens;

  const LlmUsage({
    required this.inputTokens,
    required this.outputTokens,
  });

  /// Total tokens.
  int get totalTokens => inputTokens + outputTokens;

  factory LlmUsage.fromJson(Map<String, dynamic> json) {
    return LlmUsage(
      inputTokens: json['inputTokens'] as int,
      outputTokens: json['outputTokens'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'inputTokens': inputTokens,
        'outputTokens': outputTokens,
      };
}

/// Streaming chunk from LLM.
class LlmChunk {
  /// Content delta.
  final String? content;

  /// Tool call delta.
  final LlmToolCall? toolCall;

  /// Whether this is the final chunk.
  final bool isDone;

  /// Index in the stream.
  final int? index;

  const LlmChunk({
    this.content,
    this.toolCall,
    this.isDone = false,
    this.index,
  });

  factory LlmChunk.fromJson(Map<String, dynamic> json) {
    return LlmChunk(
      content: json['content'] as String?,
      toolCall: json['toolCall'] != null
          ? LlmToolCall.fromJson(json['toolCall'] as Map<String, dynamic>)
          : null,
      isDone: json['isDone'] as bool? ?? false,
      index: json['index'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (content != null) 'content': content,
        if (toolCall != null) 'toolCall': toolCall!.toJson(),
        'isDone': isDone,
        if (index != null) 'index': index,
      };
}

/// Stub LLM port that throws on use.
class StubLlmPort implements LlmPort {
  const StubLlmPort();

  @override
  Future<LlmResponse> complete(LlmRequest request) {
    throw UnimplementedError('LlmPort not configured');
  }

  @override
  Stream<LlmChunk>? completeStream(LlmRequest request) => null;

  @override
  Future<List<double>> embed(String text) {
    throw UnimplementedError('LlmPort not configured');
  }
}
