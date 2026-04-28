/// Skill Bundle - Bundle schema implementation.
///
/// Implements the SkillBundle schema as defined in docs/spec/01-bundle-schema.md
library;

import '../definition/procedure.dart';

/// A skill bundle containing procedures and resources.
///
/// This represents the complete schema for a skill bundle as defined in
/// the spec. A skill bundle is the primary packaging format for skills.
class SkillBundle {
  // === REQUIRED ===
  /// Schema version (e.g., "0.1.0").
  final String schemaVersion;

  /// Skill manifest (identity and metadata).
  final SkillManifest manifest;

  /// Execution procedures (at least one required).
  final List<Procedure> procedures;

  // === KNOWLEDGE SECTIONS (Optional) ===
  /// Embedded files/data.
  final List<Asset>? assets;

  /// External data sources.
  final List<KnowledgeSource>? knowledgeSources;

  /// RAG/search configurations.
  final List<RetrieverConfig>? retrievers;

  /// Search index configurations.
  final List<IndexConfig>? indexes;

  // === EVALUATION SECTIONS (Optional) ===
  /// Evaluation criteria.
  final List<BundleRubric>? rubrics;

  /// Consistency/evidence rules.
  final List<BundleValidator>? validators;

  // === PRESENTATION (Optional) ===
  /// UI DSL definitions.
  final UiSection? ui;

  // === QUALITY (Optional) ===
  /// Eval sets and regression tests.
  final TestSection? tests;

  // === EXTENSIBILITY ===
  /// Custom data.
  final Map<String, dynamic>? extensions;

  const SkillBundle({
    required this.schemaVersion,
    required this.manifest,
    required this.procedures,
    this.assets,
    this.knowledgeSources,
    this.retrievers,
    this.indexes,
    this.rubrics,
    this.validators,
    this.ui,
    this.tests,
    this.extensions,
  });

  /// Create from JSON.
  factory SkillBundle.fromJson(Map<String, dynamic> json) {
    return SkillBundle(
      schemaVersion: json['schemaVersion'] as String? ?? '0.1.0',
      manifest: SkillManifest.fromJson(
          json['manifest'] as Map<String, dynamic>? ?? {}),
      procedures: (json['procedures'] as List<dynamic>?)
              ?.map((e) => Procedure.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      assets: (json['assets'] as List<dynamic>?)
          ?.map((e) => Asset.fromJson(e as Map<String, dynamic>))
          .toList(),
      knowledgeSources: (json['knowledgeSources'] as List<dynamic>?)
          ?.map((e) => KnowledgeSource.fromJson(e as Map<String, dynamic>))
          .toList(),
      retrievers: (json['retrievers'] as List<dynamic>?)
          ?.map((e) => RetrieverConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
      indexes: (json['indexes'] as List<dynamic>?)
          ?.map((e) => IndexConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
      rubrics: (json['rubrics'] as List<dynamic>?)
          ?.map((e) => BundleRubric.fromJson(e as Map<String, dynamic>))
          .toList(),
      validators: (json['validators'] as List<dynamic>?)
          ?.map((e) => BundleValidator.fromJson(e as Map<String, dynamic>))
          .toList(),
      ui: json['ui'] != null
          ? UiSection.fromJson(json['ui'] as Map<String, dynamic>)
          : null,
      tests: json['tests'] != null
          ? TestSection.fromJson(json['tests'] as Map<String, dynamic>)
          : null,
      extensions: json['extensions'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'manifest': manifest.toJson(),
        'procedures': procedures.map((e) => e.toJson()).toList(),
        if (assets != null) 'assets': assets!.map((e) => e.toJson()).toList(),
        if (knowledgeSources != null)
          'knowledgeSources': knowledgeSources!.map((e) => e.toJson()).toList(),
        if (retrievers != null)
          'retrievers': retrievers!.map((e) => e.toJson()).toList(),
        if (indexes != null)
          'indexes': indexes!.map((e) => e.toJson()).toList(),
        if (rubrics != null)
          'rubrics': rubrics!.map((e) => e.toJson()).toList(),
        if (validators != null)
          'validators': validators!.map((e) => e.toJson()).toList(),
        if (ui != null) 'ui': ui!.toJson(),
        if (tests != null) 'tests': tests!.toJson(),
        if (extensions != null) 'extensions': extensions,
      };

  /// Get procedure by ID.
  Procedure? getProcedure(String procedureId) {
    for (final proc in procedures) {
      if (proc.id == procedureId) return proc;
    }
    return null;
  }

  @override
  String toString() =>
      'SkillBundle(${manifest.id} v${manifest.version}, ${procedures.length} procedures)';
}

/// Skill manifest - Identity and metadata.
class SkillManifest {
  // === IDENTITY (Required) ===
  /// Unique skill identifier (reverse domain notation).
  final String id;

  /// Human-readable name.
  final String name;

  /// Semantic version.
  final String version;

  /// Provider/publisher identifier.
  final String provider;

  // === METADATA (Optional) ===
  /// Brief description.
  final String? description;

  /// Detailed description (markdown).
  final String? longDescription;

  /// Creator information.
  final Author? author;

  /// SPDX license identifier.
  final String? license;

  /// Project URL.
  final String? homepage;

  /// Source repository URL.
  final String? repository;

  /// Searchable keywords.
  final List<String>? keywords;

  /// Skill category.
  final String? category;

  // === CAPABILITIES (Optional) ===
  /// What this skill can do.
  final List<String>? capabilities;

  // === COMPATIBILITY (Optional) ===
  /// Compatibility configuration.
  final Map<String, dynamic>? compat;

  // === INTEGRITY (Optional) ===
  /// Checksums and signatures.
  final Map<String, dynamic>? integrity;

  // === LOCALIZATION (Optional) ===
  /// Default locale.
  final String? defaultLocale;

  /// Supported locales.
  final List<String>? supportedLocales;

  /// Localized metadata.
  final Map<String, dynamic>? localizedMetadata;

  const SkillManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.provider,
    this.description,
    this.longDescription,
    this.author,
    this.license,
    this.homepage,
    this.repository,
    this.keywords,
    this.category,
    this.capabilities,
    this.compat,
    this.integrity,
    this.defaultLocale,
    this.supportedLocales,
    this.localizedMetadata,
  });

  /// Create from JSON.
  factory SkillManifest.fromJson(Map<String, dynamic> json) {
    return SkillManifest(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      version: json['version'] as String? ?? '1.0.0',
      provider: json['provider'] as String? ?? '',
      description: json['description'] as String?,
      longDescription: json['longDescription'] as String?,
      author: json['author'] != null
          ? Author.fromJson(json['author'] as Map<String, dynamic>)
          : null,
      license: json['license'] as String?,
      homepage: json['homepage'] as String?,
      repository: json['repository'] as String?,
      keywords: (json['keywords'] as List<dynamic>?)?.cast<String>(),
      category: json['category'] as String?,
      capabilities: (json['capabilities'] as List<dynamic>?)?.cast<String>(),
      compat: json['compat'] as Map<String, dynamic>?,
      integrity: json['integrity'] as Map<String, dynamic>?,
      defaultLocale: json['defaultLocale'] as String?,
      supportedLocales:
          (json['supportedLocales'] as List<dynamic>?)?.cast<String>(),
      localizedMetadata: json['localizedMetadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        'provider': provider,
        if (description != null) 'description': description,
        if (longDescription != null) 'longDescription': longDescription,
        if (author != null) 'author': author!.toJson(),
        if (license != null) 'license': license,
        if (homepage != null) 'homepage': homepage,
        if (repository != null) 'repository': repository,
        if (keywords != null) 'keywords': keywords,
        if (category != null) 'category': category,
        if (capabilities != null) 'capabilities': capabilities,
        if (compat != null) 'compat': compat,
        if (integrity != null) 'integrity': integrity,
        if (defaultLocale != null) 'defaultLocale': defaultLocale,
        if (supportedLocales != null) 'supportedLocales': supportedLocales,
        if (localizedMetadata != null) 'localizedMetadata': localizedMetadata,
      };

  @override
  String toString() => 'SkillManifest($id: $name v$version)';
}

/// Author information.
class Author {
  final String name;
  final String? email;
  final String? url;

  const Author({required this.name, this.email, this.url});

  factory Author.fromJson(Map<String, dynamic> json) {
    return Author(
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      url: json['url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (email != null) 'email': email,
        if (url != null) 'url': url,
      };
}

/// Asset (embedded file/data).
class Asset {
  final String id;
  final String type;
  final String? path;
  final String? content;
  final Map<String, dynamic>? metadata;

  const Asset({
    required this.id,
    required this.type,
    this.path,
    this.content,
    this.metadata,
  });

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      path: json['path'] as String?,
      content: json['content'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        if (path != null) 'path': path,
        if (content != null) 'content': content,
        if (metadata != null) 'metadata': metadata,
      };
}

/// Knowledge source configuration.
class KnowledgeSource {
  final String id;
  final String type;
  final Map<String, dynamic> config;

  const KnowledgeSource({
    required this.id,
    required this.type,
    this.config = const {},
  });

  factory KnowledgeSource.fromJson(Map<String, dynamic> json) {
    return KnowledgeSource(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'file',
      config: json['config'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        if (config.isNotEmpty) 'config': config,
      };
}

/// Retriever configuration.
class RetrieverConfig {
  final String id;
  final String type;
  final Map<String, dynamic> config;

  const RetrieverConfig({
    required this.id,
    required this.type,
    this.config = const {},
  });

  factory RetrieverConfig.fromJson(Map<String, dynamic> json) {
    return RetrieverConfig(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'vector',
      config: json['config'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        if (config.isNotEmpty) 'config': config,
      };
}

/// Index configuration.
class IndexConfig {
  final String id;
  final String type;
  final Map<String, dynamic> config;

  const IndexConfig({
    required this.id,
    required this.type,
    this.config = const {},
  });

  factory IndexConfig.fromJson(Map<String, dynamic> json) {
    return IndexConfig(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'vector',
      config: json['config'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        if (config.isNotEmpty) 'config': config,
      };
}

/// Rubric definition for evaluation.
class BundleRubric {
  final String id;
  final String name;
  final List<RubricDimension> dimensions;

  const BundleRubric({
    required this.id,
    required this.name,
    this.dimensions = const [],
  });

  factory BundleRubric.fromJson(Map<String, dynamic> json) {
    return BundleRubric(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      dimensions: (json['dimensions'] as List<dynamic>?)
              ?.map((e) => RubricDimension.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dimensions': dimensions.map((e) => e.toJson()).toList(),
      };
}

/// Rubric dimension.
class RubricDimension {
  final String id;
  final String name;
  final int maxScore;

  const RubricDimension({
    required this.id,
    required this.name,
    this.maxScore = 10,
  });

  factory RubricDimension.fromJson(Map<String, dynamic> json) {
    return RubricDimension(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      maxScore: json['maxScore'] as int? ?? 10,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'maxScore': maxScore,
      };
}

/// Validator definition.
class BundleValidator {
  final String id;
  final String type;
  final Map<String, dynamic> config;

  const BundleValidator({
    required this.id,
    required this.type,
    this.config = const {},
  });

  factory BundleValidator.fromJson(Map<String, dynamic> json) {
    return BundleValidator(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'json',
      config: json['config'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        if (config.isNotEmpty) 'config': config,
      };
}

/// UI section.
class UiSection {
  final List<Map<String, dynamic>>? screens;
  final List<Map<String, dynamic>>? components;
  final Map<String, dynamic>? theme;

  const UiSection({this.screens, this.components, this.theme});

  factory UiSection.fromJson(Map<String, dynamic> json) {
    return UiSection(
      screens: (json['screens'] as List<dynamic>?)
          ?.cast<Map<String, dynamic>>(),
      components: (json['components'] as List<dynamic>?)
          ?.cast<Map<String, dynamic>>(),
      theme: json['theme'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (screens != null) 'screens': screens,
        if (components != null) 'components': components,
        if (theme != null) 'theme': theme,
      };
}

/// Test section.
class TestSection {
  final List<Map<String, dynamic>>? evalSets;
  final List<Map<String, dynamic>>? regressionTests;
  final List<Map<String, dynamic>>? benchmarks;

  const TestSection({this.evalSets, this.regressionTests, this.benchmarks});

  factory TestSection.fromJson(Map<String, dynamic> json) {
    return TestSection(
      evalSets:
          (json['evalSets'] as List<dynamic>?)?.cast<Map<String, dynamic>>(),
      regressionTests: (json['regressionTests'] as List<dynamic>?)
          ?.cast<Map<String, dynamic>>(),
      benchmarks: (json['benchmarks'] as List<dynamic>?)
          ?.cast<Map<String, dynamic>>(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (evalSets != null) 'evalSets': evalSets,
        if (regressionTests != null) 'regressionTests': regressionTests,
        if (benchmarks != null) 'benchmarks': benchmarks,
      };
}
