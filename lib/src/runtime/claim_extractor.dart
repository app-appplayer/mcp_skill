/// Claim Extractor - Full implementation with LLM strategy.
///
/// Implements all three extraction strategies: rule-based, LLM-based, and hybrid.
library;

import 'dart:convert';
import 'package:mcp_bundle/ports.dart'
    show LlmPort, LlmRequest, LlmMessage, Claim, ClaimType, ClaimStatus;
import '../id_generator.dart';

/// Claim extractor with all strategies implemented.
class ClaimExtractor {
  /// LLM port for LLM-based extraction.
  final LlmPort llmPort;

  /// Workspace ID for multi-tenant isolation.
  final String workspaceId;

  /// Extraction configuration.
  final ClaimExtractionConfig config;

  ClaimExtractor({
    required this.llmPort,
    required this.workspaceId,
    this.config = const ClaimExtractionConfig(),
  });

  /// Extract claims using configured strategy.
  Future<List<Claim>> extract(String content, {
    String? sourceId,
  }) async {
    switch (config.strategy) {
      case ClaimExtractionStrategy.none:
        return const <Claim>[];
      case ClaimExtractionStrategy.ruleBased:
        return _extractWithRules(content, sourceId: sourceId);
      case ClaimExtractionStrategy.llmBased:
        return await _extractWithLlm(content, sourceId: sourceId);
      case ClaimExtractionStrategy.hybrid:
        return await _extractHybrid(content, sourceId: sourceId);
    }
  }

  // ========================================================================
  // RULE-BASED EXTRACTION
  // ========================================================================

  List<Claim> _extractWithRules(String content, {String? sourceId}) {
    final claims = <Claim>[];
    final sentences = _segmentSentences(content);

    for (final sentence in sentences) {
      final claimType = _classifySentence(sentence);
      if (claimType != null) {
        claims.add(Claim(
          id: _generateClaimId(),
          workspaceId: workspaceId,
          type: claimType,
          text: sentence,
          sourceId: sourceId,
          evidenceRefs: const [],
          confidence: _calculateRuleBasedConfidence(sentence, claimType),
          status: ClaimStatus.pending,
          metadata: {
            'extractionMethod': 'rule_based',
            'patterns': _getMatchedPatterns(sentence, claimType),
          },
        ));
      }
    }

    return _deduplicate(claims);
  }

  List<String> _segmentSentences(String content) {
    // Split by sentence boundaries
    return content
        .split(RegExp(r'[.!?]\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  ClaimType? _classifySentence(String sentence) {
    final lower = sentence.toLowerCase();

    // Conclusion patterns
    if (_matchesPattern(lower, _conclusionPatterns)) {
      return ClaimType.conclusion;
    }

    // Recommendation patterns
    if (_matchesPattern(lower, _recommendationPatterns)) {
      return ClaimType.recommendation;
    }

    // Observation patterns
    if (_matchesPattern(lower, _observationPatterns)) {
      return ClaimType.observation;
    }

    // Prediction patterns
    if (_matchesPattern(lower, _predictionPatterns)) {
      return ClaimType.prediction;
    }

    // Fact patterns (default if contains strong indicators)
    if (_matchesPattern(lower, _factPatterns)) {
      return ClaimType.fact;
    }

    return null; // Not a claim
  }

  bool _matchesPattern(String text, List<String> patterns) {
    return patterns.any((pattern) => text.contains(pattern));
  }

  List<String> _getMatchedPatterns(String sentence, ClaimType type) {
    final lower = sentence.toLowerCase();
    final patterns = _getPatternsForType(type);
    return patterns.where((p) => lower.contains(p)).toList();
  }

  List<String> _getPatternsForType(ClaimType type) {
    switch (type) {
      case ClaimType.conclusion:
        return _conclusionPatterns;
      case ClaimType.recommendation:
        return _recommendationPatterns;
      case ClaimType.observation:
        return _observationPatterns;
      case ClaimType.prediction:
        return _predictionPatterns;
      case ClaimType.fact:
        return _factPatterns;
      default:
        return [];
    }
  }

  double _calculateRuleBasedConfidence(String sentence, ClaimType type) {
    // Base confidence
    double confidence = 0.6;

    // Boost if multiple patterns match
    final patterns = _getMatchedPatterns(sentence, type);
    confidence += patterns.length * 0.1;

    // Boost if contains evidence indicators
    if (sentence.contains(RegExp(r'\b(because|since|as|given|data shows)\b'))) {
      confidence += 0.1;
    }

    // Cap at 0.9 for rule-based (never 100% certain without LLM)
    return confidence.clamp(0.0, 0.9);
  }

  // ========================================================================
  // LLM-BASED EXTRACTION
  // ========================================================================

  Future<List<Claim>> _extractWithLlm(String content, {String? sourceId}) async {
    final prompt = _buildLlmExtractionPrompt(content);

    try {
      final response = await llmPort.complete(
        LlmRequest(
          messages: [
            LlmMessage.system(_systemPromptForExtraction),
            LlmMessage.user(prompt),
          ],
          temperature: 0.0, // Deterministic extraction
          maxTokens: 2000,
        ),
      );

      // Parse JSON response
      final claims = _parseLlmResponse(response.content, sourceId: sourceId);
      return claims;
    } catch (e) {
      // Fallback to rule-based on error
      return _extractWithRules(content, sourceId: sourceId);
    }
  }

  String _buildLlmExtractionPrompt(String content) {
    return '''
Extract all claims from the following content. For each claim, provide:
- type: one of [fact, conclusion, observation, prediction, recommendation, hypothesis, assumption]
- text: the claim statement
- confidence: 0.0 to 1.0
- evidence: supporting evidence if present in the content

Content:
$content

Respond with a JSON array of claims. Example format:
[
  {
    "type": "conclusion",
    "text": "The revenue increased by 15%",
    "confidence": 0.95,
    "evidence": "Based on Q4 financial data"
  }
]
''';
  }

  static const _systemPromptForExtraction = '''
You are a claim extraction expert. Your task is to identify and extract factual claims, conclusions, observations, predictions, recommendations, hypotheses, and assumptions from text.

Guidelines:
- A claim is a statement that asserts something to be true
- Extract only substantive claims, not trivial statements
- Assign appropriate type based on claim nature
- Provide confidence based on clarity and supporting evidence
- Be precise and concise in extracted text
''';

  List<Claim> _parseLlmResponse(String response, {String? sourceId}) {
    try {
      // Extract JSON array from response
      final jsonMatch = RegExp(r'\[(.*)\]', dotAll: true).firstMatch(response);
      if (jsonMatch == null) {
        return [];
      }

      final jsonStr = jsonMatch.group(0)!;
      final jsonList = jsonDecode(jsonStr) as List<dynamic>;

      return jsonList.map((item) {
        final map = item as Map<String, dynamic>;
        return Claim(
          id: _generateClaimId(),
          workspaceId: workspaceId,
          type: _parseClaimType(map['type'] as String?),
          text: map['text'] as String? ?? '',
          sourceId: sourceId,
          evidenceRefs: _parseEvidence(map['evidence']),
          confidence: (map['confidence'] as num?)?.toDouble() ?? 0.5,
          status: ClaimStatus.pending,
          metadata: {
            'extractionMethod': 'llm_based',
            'raw': map,
          },
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  ClaimType _parseClaimType(String? typeStr) {
    if (typeStr == null) return ClaimType.fact;

    switch (typeStr.toLowerCase()) {
      case 'conclusion':
        return ClaimType.conclusion;
      case 'recommendation':
        return ClaimType.recommendation;
      case 'observation':
        return ClaimType.observation;
      case 'prediction':
        return ClaimType.prediction;
      case 'hypothesis':
      case 'hypothetical':
        return ClaimType.hypothetical;
      case 'assumption':
        return ClaimType.fact;
      default:
        return ClaimType.fact;
    }
  }

  List<String> _parseEvidence(dynamic evidence) {
    if (evidence is String) {
      return [evidence];
    } else if (evidence is List) {
      return evidence.map((e) => e.toString()).toList();
    }
    return [];
  }

  // ========================================================================
  // HYBRID EXTRACTION
  // ========================================================================

  Future<List<Claim>> _extractHybrid(String content, {String? sourceId}) async {
    // Step 1: Extract with rules
    final ruleClaims = _extractWithRules(content, sourceId: sourceId);

    // Step 2: Identify low-confidence claims
    final lowConfidence = ruleClaims.where((c) => c.confidence < 0.7).toList();
    final highConfidence = ruleClaims.where((c) => c.confidence >= 0.7).toList();

    // Step 3: Refine low-confidence claims with LLM
    if (lowConfidence.isNotEmpty) {
      final refinedClaims = await _refineLowConfidenceClaims(
        lowConfidence,
        content,
        sourceId: sourceId,
      );
      return [...highConfidence, ...refinedClaims];
    }

    return ruleClaims;
  }

  Future<List<Claim>> _refineLowConfidenceClaims(
    List<Claim> claims,
    String originalContent, {
    String? sourceId,
  }) async {
    // Build targeted prompt for ambiguous claims
    final claimTexts = claims.map((c) => c.text).join('\n- ');
    final prompt = '''
The following statements were extracted but need verification.
For each, confirm if it's a valid claim and classify its type:

- $claimTexts

Original context:
$originalContent

Respond with JSON array of refined claims.
''';

    try {
      final response = await llmPort.complete(
        LlmRequest(
          messages: [
            LlmMessage.system(_systemPromptForExtraction),
            LlmMessage.user(prompt),
          ],
          temperature: 0.0,
          maxTokens: 1500,
        ),
      );

      return _parseLlmResponse(response.content, sourceId: sourceId);
    } catch (e) {
      // On error, return original claims with slight confidence boost
      return claims
          .map((c) => c.copyWith(confidence: (c.confidence + 0.1).clamp(0.0, 1.0)))
          .toList();
    }
  }

  // ========================================================================
  // HELPERS
  // ========================================================================

  List<Claim> _deduplicate(List<Claim> claims) {
    final seen = <String>{};
    final unique = <Claim>[];

    for (final claim in claims) {
      final normalized = claim.text.toLowerCase().trim();
      if (!seen.contains(normalized)) {
        seen.add(normalized);
        unique.add(claim);
      }
    }

    return unique;
  }

  String _generateClaimId() {
    return generateId('claim');
  }

  // ========================================================================
  // PATTERNS
  // ========================================================================

  static const _conclusionPatterns = [
    'therefore',
    'thus',
    'consequently',
    'as a result',
    'this suggests',
    'this indicates',
    'we conclude',
    'in conclusion',
    'the evidence shows',
  ];

  static const _recommendationPatterns = [
    'should',
    'recommend',
    'suggest',
    'advise',
    'ought to',
    'it would be beneficial',
    'consider',
    'propose',
  ];

  static const _observationPatterns = [
    'observed',
    'noticed',
    'found that',
    'appears that',
    'seems that',
    'evident that',
    'clear that',
  ];

  static const _predictionPatterns = [
    'will',
    'expect',
    'forecast',
    'anticipate',
    'predict',
    'likely',
    'probably',
    'in the future',
  ];

  static const _factPatterns = [
    'is',
    'are',
    'was',
    'were',
    'has',
    'have',
    'contains',
    'includes',
  ];
}

/// Claim extraction configuration.
class ClaimExtractionConfig {
  /// Extraction strategy to use.
  final ClaimExtractionStrategy strategy;

  /// Minimum confidence threshold.
  final double minConfidence;

  /// Maximum claims to extract.
  final int? maxClaims;

  const ClaimExtractionConfig({
    this.strategy = ClaimExtractionStrategy.hybrid,
    this.minConfidence = 0.5,
    this.maxClaims,
  });
}

/// Claim extraction strategy.
enum ClaimExtractionStrategy {
  /// No extraction: the reply is only the step's text. No claims, and no
  /// extra LLM call.
  none,

  /// Rule-based pattern matching.
  ruleBased,

  /// LLM-based extraction.
  llmBased,

  /// Hybrid: rules first, LLM for refinement.
  hybrid,
}
