/// Knowledge Port - Abstract interface for knowledge/RAG operations.
///
/// Defines contracts for knowledge retrieval and asset access in skill execution.
library;

/// Port for knowledge/RAG operations.
abstract class KnowledgePort {
  /// Query a retriever for relevant passages.
  Future<RetrievalResult> query(
    String retrieverId,
    String query, {
    Map<String, dynamic>? filters,
    int? maxResults,
  });

  /// Get an asset by ID.
  Future<AssetContent> getAsset(String assetId);

  /// Open a stream to an asset.
  Stream<List<int>> streamAsset(String assetId);

  /// List available retrievers.
  Future<List<RetrieverInfo>> listRetrievers();

  /// Check if an index exists.
  Future<bool> indexExists(String indexId);

  /// Build an index (if supported).
  Future<void> buildIndex(String indexId, IndexBuildConfig config);
}

/// Retrieval result.
class RetrievalResult {
  /// Retrieved passages.
  final List<RetrievedPassage> passages;

  /// Additional metadata.
  final Map<String, dynamic>? metadata;

  /// Total number of matches (may be greater than passages.length).
  final int? totalMatches;

  const RetrievalResult({
    required this.passages,
    this.metadata,
    this.totalMatches,
  });

  /// Whether any passages were found.
  bool get isEmpty => passages.isEmpty;

  /// Whether passages were found.
  bool get isNotEmpty => passages.isNotEmpty;

  factory RetrievalResult.fromJson(Map<String, dynamic> json) {
    return RetrievalResult(
      passages: (json['passages'] as List<dynamic>)
          .map((e) => RetrievedPassage.fromJson(e as Map<String, dynamic>))
          .toList(),
      metadata: json['metadata'] as Map<String, dynamic>?,
      totalMatches: json['totalMatches'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'passages': passages.map((p) => p.toJson()).toList(),
        if (metadata != null) 'metadata': metadata,
        if (totalMatches != null) 'totalMatches': totalMatches,
      };
}

/// Retrieved passage.
class RetrievedPassage {
  /// Passage identifier.
  final String id;

  /// Passage content.
  final String content;

  /// Relevance score.
  final double score;

  /// Source document ID.
  final String? sourceId;

  /// Source URI.
  final String? sourceUri;

  /// Position in source document.
  final PassagePosition? position;

  /// Additional metadata.
  final Map<String, dynamic>? metadata;

  const RetrievedPassage({
    required this.id,
    required this.content,
    required this.score,
    this.sourceId,
    this.sourceUri,
    this.position,
    this.metadata,
  });

  factory RetrievedPassage.fromJson(Map<String, dynamic> json) {
    return RetrievedPassage(
      id: json['id'] as String,
      content: json['content'] as String,
      score: (json['score'] as num).toDouble(),
      sourceId: json['sourceId'] as String?,
      sourceUri: json['sourceUri'] as String?,
      position: json['position'] != null
          ? PassagePosition.fromJson(json['position'] as Map<String, dynamic>)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'score': score,
        if (sourceId != null) 'sourceId': sourceId,
        if (sourceUri != null) 'sourceUri': sourceUri,
        if (position != null) 'position': position!.toJson(),
        if (metadata != null) 'metadata': metadata,
      };
}

/// Position of passage in source document.
class PassagePosition {
  /// Start character offset.
  final int? startOffset;

  /// End character offset.
  final int? endOffset;

  /// Page number (for PDFs).
  final int? page;

  /// Section identifier.
  final String? section;

  const PassagePosition({
    this.startOffset,
    this.endOffset,
    this.page,
    this.section,
  });

  factory PassagePosition.fromJson(Map<String, dynamic> json) {
    return PassagePosition(
      startOffset: json['startOffset'] as int?,
      endOffset: json['endOffset'] as int?,
      page: json['page'] as int?,
      section: json['section'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (startOffset != null) 'startOffset': startOffset,
        if (endOffset != null) 'endOffset': endOffset,
        if (page != null) 'page': page,
        if (section != null) 'section': section,
      };
}

/// Asset content.
class AssetContent {
  /// Asset identifier.
  final String assetId;

  /// MIME type.
  final String mimeType;

  /// Content (String or bytes).
  final dynamic content;

  /// Size in bytes.
  final int? size;

  /// Content hash.
  final String? hash;

  /// Additional metadata.
  final Map<String, dynamic>? metadata;

  const AssetContent({
    required this.assetId,
    required this.mimeType,
    required this.content,
    this.size,
    this.hash,
    this.metadata,
  });

  /// Get content as string.
  String? get asString => content is String ? content as String : null;

  /// Get content as bytes.
  List<int>? get asBytes => content is List<int> ? content as List<int> : null;

  factory AssetContent.fromJson(Map<String, dynamic> json) {
    return AssetContent(
      assetId: json['assetId'] as String,
      mimeType: json['mimeType'] as String,
      content: json['content'],
      size: json['size'] as int?,
      hash: json['hash'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'assetId': assetId,
        'mimeType': mimeType,
        'content': content,
        if (size != null) 'size': size,
        if (hash != null) 'hash': hash,
        if (metadata != null) 'metadata': metadata,
      };
}

/// Retriever information.
class RetrieverInfo {
  /// Retriever identifier.
  final String id;

  /// Retriever name.
  final String name;

  /// Retriever type.
  final String type;

  /// Source references.
  final List<String> sourceRefs;

  /// Description.
  final String? description;

  const RetrieverInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.sourceRefs,
    this.description,
  });

  factory RetrieverInfo.fromJson(Map<String, dynamic> json) {
    return RetrieverInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      sourceRefs: (json['sourceRefs'] as List<dynamic>).cast<String>(),
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'sourceRefs': sourceRefs,
        if (description != null) 'description': description,
      };
}

/// Index build configuration.
class IndexBuildConfig {
  /// Asset references to index.
  final List<String> assetRefs;

  /// Source references.
  final List<String>? sourceRefs;

  /// Embedding model to use.
  final String? embeddingModel;

  /// Chunk size in characters.
  final int? chunkSize;

  /// Chunk overlap in characters.
  final int? chunkOverlap;

  /// Additional options.
  final Map<String, dynamic>? options;

  const IndexBuildConfig({
    required this.assetRefs,
    this.sourceRefs,
    this.embeddingModel,
    this.chunkSize,
    this.chunkOverlap,
    this.options,
  });

  factory IndexBuildConfig.fromJson(Map<String, dynamic> json) {
    return IndexBuildConfig(
      assetRefs: (json['assetRefs'] as List<dynamic>).cast<String>(),
      sourceRefs: (json['sourceRefs'] as List<dynamic>?)?.cast<String>(),
      embeddingModel: json['embeddingModel'] as String?,
      chunkSize: json['chunkSize'] as int?,
      chunkOverlap: json['chunkOverlap'] as int?,
      options: json['options'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'assetRefs': assetRefs,
        if (sourceRefs != null) 'sourceRefs': sourceRefs,
        if (embeddingModel != null) 'embeddingModel': embeddingModel,
        if (chunkSize != null) 'chunkSize': chunkSize,
        if (chunkOverlap != null) 'chunkOverlap': chunkOverlap,
        if (options != null) 'options': options,
      };
}

/// Exception when asset is not found.
class AssetNotFoundException implements Exception {
  /// Asset ID that was not found.
  final String assetId;

  AssetNotFoundException(this.assetId);

  @override
  String toString() => 'AssetNotFoundException: Asset not found: $assetId';
}

/// Exception when retriever is not found.
class RetrieverNotFoundException implements Exception {
  /// Retriever ID that was not found.
  final String retrieverId;

  RetrieverNotFoundException(this.retrieverId);

  @override
  String toString() =>
      'RetrieverNotFoundException: Retriever not found: $retrieverId';
}

/// Stub knowledge port with no data.
class EmptyKnowledgePort implements KnowledgePort {
  const EmptyKnowledgePort();

  @override
  Future<RetrievalResult> query(
    String retrieverId,
    String query, {
    Map<String, dynamic>? filters,
    int? maxResults,
  }) async {
    return const RetrievalResult(passages: []);
  }

  @override
  Future<AssetContent> getAsset(String assetId) {
    throw AssetNotFoundException(assetId);
  }

  @override
  Stream<List<int>> streamAsset(String assetId) {
    throw AssetNotFoundException(assetId);
  }

  @override
  Future<List<RetrieverInfo>> listRetrievers() async => [];

  @override
  Future<bool> indexExists(String indexId) async => false;

  @override
  Future<void> buildIndex(String indexId, IndexBuildConfig config) async {
    throw UnimplementedError('Index building not supported');
  }
}
