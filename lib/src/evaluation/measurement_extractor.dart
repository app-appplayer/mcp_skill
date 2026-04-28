/// Measurement Extractor - Extracts measurements from artifacts.
///
/// Provides the measurement extraction interface and built-in extractors
/// for code analysis, security scanning, test coverage, and more.
library;

import 'dart:convert';

import 'package:mcp_bundle/mcp_bundle.dart' show RetrievalPort;

import 'rubric.dart';
import '../ports/llm_port.dart';
import '../runtime/skill_result.dart';

/// Configuration for measurement extraction.
class ExtractorConfig {
  /// Metric to extract.
  final String? metric;

  /// Query for metric retrieval.
  final String? query;

  /// Retriever reference.
  final String? retrieverRef;

  /// Extraction prompt for LLM.
  final String? extractionPrompt;

  /// Additional configuration.
  final Map<String, dynamic>? additional;

  const ExtractorConfig({
    this.metric,
    this.query,
    this.retrieverRef,
    this.extractionPrompt,
    this.additional,
  });

  factory ExtractorConfig.fromJson(Map<String, dynamic> json) {
    return ExtractorConfig(
      metric: json['metric'] as String?,
      query: json['query'] as String?,
      retrieverRef: json['retrieverRef'] as String?,
      extractionPrompt: json['extractionPrompt'] as String?,
      additional: json['additional'] as Map<String, dynamic>?,
    );
  }
}

/// Base class for measurement extractors.
abstract class MeasurementExtractor {
  /// Dimension ID this extractor targets.
  final String dimensionId;

  MeasurementExtractor(this.dimensionId);

  /// Extract measurement from artifact.
  Future<DimensionMeasurement> extract(
    Artifact artifact,
    ExtractorConfig config,
  );
}

/// Factory for creating measurement extractors.
typedef MeasurementExtractorFactory = MeasurementExtractor Function(
    String dimensionId);

/// Registry for measurement extractors.
class MeasurementExtractorRegistry {
  final Map<String, MeasurementExtractorFactory> _factories = {};

  /// LLM port for LLM-based extraction.
  final LlmPort? llmPort;

  /// Retrieval port for metric queries.
  final RetrievalPort? retrievalPort;

  MeasurementExtractorRegistry({
    this.llmPort,
    this.retrievalPort,
  }) {
    _registerBuiltInExtractors();
  }

  void _registerBuiltInExtractors() {
    register('code_complexity',
        (dimensionId) => CodeComplexityExtractor(dimensionId));
    register(
        'security_scan', (dimensionId) => SecurityScanExtractor(dimensionId));
    register(
        'test_coverage', (dimensionId) => TestCoverageExtractor(dimensionId));
    register('documentation_check',
        (dimensionId) => DocumentationExtractor(dimensionId));
    register('dependency_audit',
        (dimensionId) => DependencyAuditExtractor(dimensionId));
    register('metric_query',
        (dimensionId) => MetricQueryExtractor(dimensionId, retrievalPort));
    register('manual', (dimensionId) => ManualExtractor(dimensionId));

    if (llmPort != null) {
      register('llm_extraction',
          (dimensionId) => LlmExtractionExtractor(dimensionId, llmPort!));
    }
  }

  /// Register an extractor factory.
  void register(String extractorType, MeasurementExtractorFactory factory) {
    _factories[extractorType] = factory;
  }

  /// Get an extractor for the given type.
  MeasurementExtractor getExtractor(String extractorType, String dimensionId) {
    final factory = _factories[extractorType];
    if (factory == null) {
      throw UnknownExtractorException(extractorType);
    }
    return factory(dimensionId);
  }

  /// Check if an extractor type is registered.
  bool hasExtractor(String extractorType) =>
      _factories.containsKey(extractorType);
}

/// Code complexity extractor.
class CodeComplexityExtractor extends MeasurementExtractor {
  CodeComplexityExtractor(super.dimensionId);

  @override
  Future<DimensionMeasurement> extract(
    Artifact artifact,
    ExtractorConfig config,
  ) async {
    final metric = config.metric ?? 'cyclomatic_complexity';
    final content = artifact.content?.toString() ?? '';

    // Simple complexity analysis based on code patterns
    double complexity = 0;

    switch (metric) {
      case 'cyclomatic_complexity':
        complexity = _calculateCyclomaticComplexity(content);
        break;
      case 'lines_of_code':
        complexity = _countLinesOfCode(content).toDouble();
        break;
      case 'nesting_depth':
        complexity = _calculateMaxNestingDepth(content).toDouble();
        break;
      default:
        complexity = _calculateCyclomaticComplexity(content);
    }

    return DimensionMeasurement(
      dimensionId: dimensionId,
      value: complexity,
      confidence: 1.0,
      source: MeasurementSource.codeAnalysis(
        tool: 'complexity_analyzer',
        version: '1.0.0',
      ),
      metadata: {'metric': metric},
    );
  }

  double _calculateCyclomaticComplexity(String content) {
    // Count decision points: if, else, while, for, case, catch, &&, ||, ?:
    final patterns = [
      RegExp(r'\bif\b'),
      RegExp(r'\belse\s+if\b'),
      RegExp(r'\bwhile\b'),
      RegExp(r'\bfor\b'),
      RegExp(r'\bcase\b'),
      RegExp(r'\bcatch\b'),
      RegExp(r'&&'),
      RegExp(r'\|\|'),
      RegExp(r'\?\s*:'),
    ];

    int count = 1; // Base complexity
    for (final pattern in patterns) {
      count += pattern.allMatches(content).length;
    }

    return count.toDouble();
  }

  int _countLinesOfCode(String content) {
    final lines = content.split('\n');
    return lines
        .where((line) => line.trim().isNotEmpty && !line.trim().startsWith('//'))
        .length;
  }

  int _calculateMaxNestingDepth(String content) {
    int maxDepth = 0;
    int currentDepth = 0;

    for (final char in content.runes) {
      if (char == '{'.codeUnitAt(0)) {
        currentDepth++;
        if (currentDepth > maxDepth) maxDepth = currentDepth;
      } else if (char == '}'.codeUnitAt(0)) {
        currentDepth--;
      }
    }

    return maxDepth;
  }
}

/// Security scan extractor.
class SecurityScanExtractor extends MeasurementExtractor {
  SecurityScanExtractor(super.dimensionId);

  @override
  Future<DimensionMeasurement> extract(
    Artifact artifact,
    ExtractorConfig config,
  ) async {
    final content = artifact.content?.toString() ?? '';
    final findings = _scanForVulnerabilities(content);

    // Convert findings to score (100 = no issues)
    final score = _calculateSecurityScore(findings);

    return DimensionMeasurement(
      dimensionId: dimensionId,
      value: score,
      confidence: 0.95,
      source: MeasurementSource.codeAnalysis(
        tool: 'security_scanner',
        version: '1.0.0',
      ),
      metadata: {
        'findings': findings,
        'findingCount': findings.length,
      },
    );
  }

  List<Map<String, dynamic>> _scanForVulnerabilities(String content) {
    final findings = <Map<String, dynamic>>[];

    // Check for common security issues
    final vulnerabilityPatterns = {
      'hardcoded_secret': {
        'pattern': RegExp(
            r'(password|secret|api_key|apikey)\s*=\s*["\x27][^"\x27]+["\x27]',
            caseSensitive: false),
        'severity': 'critical',
      },
      'sql_injection': {
        'pattern': RegExp(r'\$\{.*\}.*SELECT|SELECT.*\+.*variable',
            caseSensitive: false),
        'severity': 'high',
      },
      'eval_usage': {
        'pattern': RegExp(r'\beval\s*\('),
        'severity': 'high',
      },
      'http_url': {
        'pattern': RegExp(r'http://(?!localhost)', caseSensitive: false),
        'severity': 'medium',
      },
    };

    for (final entry in vulnerabilityPatterns.entries) {
      final pattern = entry.value['pattern'] as RegExp;
      final matches = pattern.allMatches(content);
      for (final match in matches) {
        findings.add({
          'type': entry.key,
          'severity': entry.value['severity'],
          'location': match.start,
          'snippet': match.group(0),
        });
      }
    }

    return findings;
  }

  double _calculateSecurityScore(List<Map<String, dynamic>> findings) {
    if (findings.isEmpty) return 100.0;

    int criticalCount = 0;
    int highCount = 0;
    int mediumCount = 0;
    int lowCount = 0;

    for (final finding in findings) {
      switch (finding['severity']) {
        case 'critical':
          criticalCount++;
          break;
        case 'high':
          highCount++;
          break;
        case 'medium':
          mediumCount++;
          break;
        case 'low':
          lowCount++;
          break;
      }
    }

    // Weighted penalty
    final penalty =
        criticalCount * 25 + highCount * 15 + mediumCount * 5 + lowCount * 1;
    return (100.0 - penalty).clamp(0.0, 100.0);
  }
}

/// Test coverage extractor.
class TestCoverageExtractor extends MeasurementExtractor {
  TestCoverageExtractor(super.dimensionId);

  @override
  Future<DimensionMeasurement> extract(
    Artifact artifact,
    ExtractorConfig config,
  ) async {
    // Look for coverage data in artifact metadata
    final coverageData = artifact.metadata?['coverage'];
    double coverage;

    if (coverageData != null) {
      coverage = (coverageData as num).toDouble();
    } else {
      // Estimate based on test presence
      final content = artifact.content?.toString() ?? '';
      coverage = _estimateCoverage(content);
    }

    return DimensionMeasurement(
      dimensionId: dimensionId,
      value: coverage,
      confidence: coverageData != null ? 1.0 : 0.7,
      source: MeasurementSource.codeAnalysis(
        tool: 'coverage_reporter',
        version: '1.0.0',
      ),
    );
  }

  double _estimateCoverage(String content) {
    // Simple heuristic: presence of test-related keywords
    final hasTests = content.contains('test(') ||
        content.contains('expect(') ||
        content.contains('@Test') ||
        content.contains('it(\'');
    return hasTests ? 70.0 : 0.0;
  }
}

/// Documentation extractor.
class DocumentationExtractor extends MeasurementExtractor {
  DocumentationExtractor(super.dimensionId);

  @override
  Future<DimensionMeasurement> extract(
    Artifact artifact,
    ExtractorConfig config,
  ) async {
    final content = artifact.content?.toString() ?? '';
    final score = _calculateDocumentationScore(content);

    return DimensionMeasurement(
      dimensionId: dimensionId,
      value: score,
      confidence: 0.9,
      source: MeasurementSource.codeAnalysis(
        tool: 'documentation_checker',
        version: '1.0.0',
      ),
    );
  }

  double _calculateDocumentationScore(String content) {
    // Count documentation indicators
    final docCommentCount = RegExp(r'///|/\*\*').allMatches(content).length;
    final functionCount =
        RegExp(r'\b(function|def|func|void|int|String|Future)\s+\w+\s*\(')
            .allMatches(content)
            .length;
    final classCount =
        RegExp(r'\b(class|interface|struct)\s+\w+').allMatches(content).length;

    if (functionCount + classCount == 0) return 100.0;

    final ratio =
        docCommentCount / (functionCount + classCount).clamp(1, 1000);
    return (ratio * 100).clamp(0.0, 100.0);
  }
}

/// Dependency audit extractor.
class DependencyAuditExtractor extends MeasurementExtractor {
  DependencyAuditExtractor(super.dimensionId);

  @override
  Future<DimensionMeasurement> extract(
    Artifact artifact,
    ExtractorConfig config,
  ) async {
    final content = artifact.content?.toString() ?? '';
    final score = _auditDependencies(content);

    return DimensionMeasurement(
      dimensionId: dimensionId,
      value: score,
      confidence: 0.85,
      source: MeasurementSource.codeAnalysis(
        tool: 'dependency_auditor',
        version: '1.0.0',
      ),
    );
  }

  double _auditDependencies(String content) {
    // Check for dependency declaration patterns
    final hasDependencies = content.contains('dependencies:') ||
        content.contains('require(') ||
        content.contains('import ') ||
        content.contains('package ');

    // Assume 80 as baseline for having dependencies
    if (!hasDependencies) return 100.0;

    // Penalize for pinned versions (often outdated) vs ranges
    final pinnedCount =
        RegExp(r':\s*\d+\.\d+\.\d+').allMatches(content).length;
    final rangeCount =
        RegExp(r':\s*[\^~>=<]').allMatches(content).length;

    if (pinnedCount + rangeCount == 0) return 100.0;

    final rangeRatio = rangeCount / (pinnedCount + rangeCount);
    return (60 + rangeRatio * 40).clamp(0.0, 100.0);
  }
}

/// Metric query extractor.
class MetricQueryExtractor extends MeasurementExtractor {
  final RetrievalPort? retrievalPort;

  MetricQueryExtractor(super.dimensionId, this.retrievalPort);

  @override
  Future<DimensionMeasurement> extract(
    Artifact artifact,
    ExtractorConfig config,
  ) async {
    final query = config.query ?? 'SELECT value FROM metrics WHERE dimension_id = ?';

    if (retrievalPort != null) {
      try {
        final result = await retrievalPort!.queryKnowledge(
          query,
          retrieverId: config.retrieverRef ?? 'metrics',
          filters: {
            'artifact_id': artifact.id,
            'dimension_id': dimensionId,
          },
        );

        if (result.passages.isNotEmpty) {
          final value =
              double.tryParse(result.passages.first.content) ?? 0.0;
          return DimensionMeasurement(
            dimensionId: dimensionId,
            value: value,
            confidence: 1.0,
            source: MeasurementSource.metricQuery(query: query),
          );
        }
      } catch (_) {
        // Fall through to default
      }
    }

    return DimensionMeasurement(
      dimensionId: dimensionId,
      value: 0.0,
      confidence: 0.5,
      source: MeasurementSource.metricQuery(query: query),
      metadata: {'warning': 'No metric found, using default'},
    );
  }
}

/// Manual measurement extractor (passthrough).
class ManualExtractor extends MeasurementExtractor {
  ManualExtractor(super.dimensionId);

  @override
  Future<DimensionMeasurement> extract(
    Artifact artifact,
    ExtractorConfig config,
  ) async {
    // Manual extractor expects value to be provided in config
    final value = config.additional?['value'] ?? 0.0;

    return DimensionMeasurement(
      dimensionId: dimensionId,
      value: value,
      confidence: 1.0,
      source: MeasurementSource.manual(userId: 'system'),
    );
  }
}

/// LLM-based extraction extractor.
class LlmExtractionExtractor extends MeasurementExtractor {
  final LlmPort llmPort;

  LlmExtractionExtractor(super.dimensionId, this.llmPort);

  @override
  Future<DimensionMeasurement> extract(
    Artifact artifact,
    ExtractorConfig config,
  ) async {
    final extractionPrompt =
        config.extractionPrompt ?? _buildDefaultPrompt(config);
    final content = artifact.content?.toString() ?? '';

    final response = await llmPort.complete(LlmRequest(
      messages: [
        const LlmMessage(
          role: 'system',
          content: '''You are an objective measurement extractor.
Extract specific metrics from the artifact.
Do NOT provide scores or evaluations. Only extract raw measurements.
Respond with JSON in the specified format.''',
        ),
        LlmMessage(
          role: 'user',
          content: '''Artifact: $content

$extractionPrompt

Expected output format:
{
  "value": <extracted value>,
  "confidence": <0-1 confidence in extraction>,
  "reasoning": "<brief explanation>"
}''',
        ),
      ],
    ));

    try {
      final extracted = jsonDecode(response.content) as Map<String, dynamic>;

      return DimensionMeasurement(
        dimensionId: dimensionId,
        value: extracted['value'],
        confidence:
            (extracted['confidence'] as num?)?.toDouble() ?? 0.8,
        source: MeasurementSource.evidenceExtraction(
          evidenceId: artifact.id,
        ),
        metadata: {'reasoning': extracted['reasoning']},
      );
    } catch (e) {
      // Fallback if JSON parsing fails
      return DimensionMeasurement(
        dimensionId: dimensionId,
        value: 0.0,
        confidence: 0.3,
        source: MeasurementSource.evidenceExtraction(
          evidenceId: artifact.id,
        ),
        metadata: {'error': 'Failed to parse LLM response: $e'},
      );
    }
  }

  String _buildDefaultPrompt(ExtractorConfig config) {
    return 'Extract measurement for: ${config.metric ?? dimensionId}';
  }
}

/// Exception for unknown extractor types.
class UnknownExtractorException implements Exception {
  final String extractorType;

  UnknownExtractorException(this.extractorType);

  @override
  String toString() =>
      'UnknownExtractorException: Unknown measurement extractor type: $extractorType';
}
