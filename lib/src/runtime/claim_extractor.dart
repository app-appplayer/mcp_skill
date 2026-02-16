/// Claim Extractor - Extracts claims from LLM responses.
///
/// Provides rule-based, LLM-based, and hybrid claim extraction
/// strategies for processing skill execution outputs.
library;

import 'dart:math';

import 'skill_result.dart';
import '../ports/llm_port.dart';

/// Claim extraction strategies and algorithms.
class ClaimExtractor {
  /// Extraction configuration.
  final ClaimExtractionConfig config;

  /// LLM port for LLM-based extraction.
  final LlmPort? llmPort;

  ClaimExtractor({
    required this.config,
    this.llmPort,
  });

  /// Extract claims using configured strategy.
  List<Claim> extract(String content) {
    switch (config.strategy) {
      case ClaimExtractionStrategy.ruleBased:
        return _extractWithRules(content);
      case ClaimExtractionStrategy.llmBased:
        return _extractWithLlm(content);
      case ClaimExtractionStrategy.hybrid:
        return _extractHybrid(content);
    }
  }

  /// Rule-based extraction using pattern matching.
  List<Claim> _extractWithRules(String content) {
    final claims = <Claim>[];
    final sentences = _segmentSentences(content);

    for (final sentence in sentences) {
      final claimType = _classifySentence(sentence);
      if (claimType != null) {
        claims.add(Claim(
          id: _generateClaimId(),
          type: claimType,
          text: sentence.text,
          evidenceRefs: _findEvidenceRefs(sentence, sentences),
          confidence: _calculateConfidence(sentence, claimType),
          metadata: {
            'extractionMethod': 'rule_based',
            'patterns': sentence.matchedPatterns,
          },
        ));
      }
    }

    return _deduplicateAndRank(claims);
  }

  /// LLM-based extraction for complex content.
  List<Claim> _extractWithLlm(String content) {
    if (llmPort == null) {
      // Fallback to rule-based if no LLM
      return _extractWithRules(content);
    }

    // LLM extraction would be async in production
    // For now, return empty list and use rules
    return _extractWithRules(content);
  }

  /// Hybrid: rules first, LLM for ambiguous cases.
  List<Claim> _extractHybrid(String content) {
    final ruleClaims = _extractWithRules(content);
    final lowConfidence = ruleClaims.where((c) => c.confidence < 0.5).toList();

    if (lowConfidence.isNotEmpty && llmPort != null) {
      // In production, would re-process low confidence claims with LLM
      // For now, just return rule-based results
    }

    return ruleClaims;
  }

  /// Segment content into sentences with metadata.
  List<SentenceSegment> _segmentSentences(String content) {
    final segments = <SentenceSegment>[];

    // Split by sentence boundaries (. ! ? and line breaks)
    final sentencePattern = RegExp(r'([^.!?\n]+[.!?]?)');
    int position = 0;

    for (final match in sentencePattern.allMatches(content)) {
      final text = match.group(0)?.trim() ?? '';
      if (text.isNotEmpty && text.length > 3) {
        segments.add(SentenceSegment(
          text: text,
          position: position,
          index: segments.length,
        ));
      }
      position = match.end;
    }

    return segments;
  }

  /// Classify sentence into claim type using pattern matching.
  ClaimType? _classifySentence(SentenceSegment sentence) {
    final text = sentence.text.toLowerCase();
    final patterns = sentence.matchedPatterns;

    // Conclusion indicators
    if (_matchesPatterns(text, [
      r'\b(therefore|thus|hence|consequently|as a result)\b',
      r'\b(in conclusion|to conclude|finally|ultimately)\b',
      r'\b(this means|this shows|this proves|this indicates)\b',
    ])) {
      patterns.add('conclusion_indicator');
      return ClaimType.conclusion;
    }

    // Observation indicators
    if (_matchesPatterns(text, [
      r'\b(observed|noticed|found|detected|identified)\b',
      r'\b(shows that|reveals that|indicates that)\b',
      r'\b(data shows|results show|analysis shows)\b',
    ])) {
      patterns.add('observation_indicator');
      return ClaimType.observation;
    }

    // Prediction indicators
    if (_matchesPatterns(text, [
      r'\b(will|would|should|likely|probably)\b',
      r'\b(predicts?|expects?|anticipates?|forecasts?)\b',
      r'\b(in the future|going forward|eventually)\b',
    ])) {
      patterns.add('prediction_indicator');
      return ClaimType.prediction;
    }

    // Recommendation indicators
    if (_matchesPatterns(text, [
      r'\b(recommend|suggest|advise|propose)\b',
      r'\b(should consider|ought to|best to)\b',
      r'\b(it is recommended|we recommend)\b',
    ])) {
      patterns.add('recommendation_indicator');
      return ClaimType.recommendation;
    }

    // Factual claim indicators
    if (_matchesPatterns(text, [
      r'\b(is|are|was|were)\b.*\b(the|a|an)\b',
      r'\b\d+(\.\d+)?%\b', // Contains percentages
      r'\b\d{4}\b', // Contains years
    ])) {
      patterns.add('factual_indicator');
      return ClaimType.fact;
    }

    // No strong signal - skip or mark as unknown
    return null;
  }

  bool _matchesPatterns(String text, List<String> patterns) {
    return patterns.any((p) => RegExp(p, caseSensitive: false).hasMatch(text));
  }

  /// Find evidence references for a claim.
  List<String> _findEvidenceRefs(
    SentenceSegment claimSentence,
    List<SentenceSegment> allSentences,
  ) {
    final refs = <String>[];

    // Look for citation patterns
    final citationPattern = RegExp(r'\[(\d+)\]|\(([A-Za-z]+,?\s*\d{4})\)');
    for (final match in citationPattern.allMatches(claimSentence.text)) {
      refs.add(match.group(0) ?? '');
    }

    // Find supporting sentences (previous sentences with data/evidence)
    final claimIndex = claimSentence.index;
    for (int i = max(0, claimIndex - 3); i < claimIndex; i++) {
      final prev = allSentences[i];
      if (_isEvidenceSentence(prev)) {
        refs.add('sentence_$i');
      }
    }

    return refs;
  }

  bool _isEvidenceSentence(SentenceSegment sentence) {
    final text = sentence.text.toLowerCase();
    return _matchesPatterns(text, [
      r'\b\d+(\.\d+)?%\b', // Contains percentages
      r'\b(study|research|survey)\b', // Research references
      r'\b(according to|based on)\b', // Attribution
      r'\b(table|figure|chart)\s*\d', // Data references
    ]);
  }

  /// Calculate confidence based on pattern strength.
  double _calculateConfidence(SentenceSegment sentence, ClaimType type) {
    double confidence = 0.5; // Base confidence

    // Boost for strong indicator patterns
    if (sentence.matchedPatterns.length > 1) {
      confidence += 0.1 * sentence.matchedPatterns.length;
    }

    // Boost for explicit language
    if (sentence.text.contains('clearly') ||
        sentence.text.contains('definitely') ||
        sentence.text.contains('certainly')) {
      confidence += 0.1;
    }

    // Reduce for hedging language
    if (sentence.text.contains('might') ||
        sentence.text.contains('perhaps') ||
        sentence.text.contains('possibly')) {
      confidence -= 0.15;
    }

    // Reduce for very short claims
    if (sentence.text.split(' ').length < 5) {
      confidence -= 0.1;
    }

    return confidence.clamp(0.1, 0.95);
  }

  /// Deduplicate similar claims and rank by confidence.
  List<Claim> _deduplicateAndRank(List<Claim> claims) {
    if (claims.isEmpty) return claims;

    // Group by similarity (simple word overlap)
    final groups = <List<Claim>>[];
    final used = <int>{};

    for (int i = 0; i < claims.length; i++) {
      if (used.contains(i)) continue;

      final group = [claims[i]];
      used.add(i);

      for (int j = i + 1; j < claims.length; j++) {
        if (used.contains(j)) continue;
        if (_areSimilar(claims[i], claims[j])) {
          group.add(claims[j]);
          used.add(j);
        }
      }
      groups.add(group);
    }

    // Take highest confidence from each group
    final deduplicated = groups.map((group) {
      group.sort((a, b) => b.confidence.compareTo(a.confidence));
      return group.first;
    }).toList();

    // Sort by confidence descending
    deduplicated.sort((a, b) => b.confidence.compareTo(a.confidence));

    // Limit to max claims
    if (deduplicated.length > config.maxClaimsPerContent) {
      return deduplicated.sublist(0, config.maxClaimsPerContent);
    }

    return deduplicated;
  }

  bool _areSimilar(Claim a, Claim b) {
    final wordsA = a.text.toLowerCase().split(RegExp(r'\s+'));
    final wordsB = b.text.toLowerCase().split(RegExp(r'\s+'));

    final intersection = wordsA.toSet().intersection(wordsB.toSet());
    final union = wordsA.toSet().union(wordsB.toSet());

    final jaccardSimilarity = intersection.length / union.length;
    return jaccardSimilarity > 0.6; // 60% word overlap threshold
  }

  String _generateClaimId() =>
      'claim_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1000)}';

  static final _random = Random();
}

/// Configuration for claim extraction.
class ClaimExtractionConfig {
  /// Extraction strategy.
  final ClaimExtractionStrategy strategy;

  /// Minimum confidence threshold.
  final double minConfidenceThreshold;

  /// Maximum claims per content.
  final int maxClaimsPerContent;

  /// Target claim types to extract.
  final List<ClaimType> targetTypes;

  const ClaimExtractionConfig({
    this.strategy = ClaimExtractionStrategy.ruleBased,
    this.minConfidenceThreshold = 0.3,
    this.maxClaimsPerContent = 10,
    this.targetTypes = const [
      ClaimType.conclusion,
      ClaimType.observation,
      ClaimType.prediction,
      ClaimType.recommendation,
      ClaimType.fact,
    ],
  });
}

/// Claim extraction strategies.
enum ClaimExtractionStrategy {
  /// Pattern matching only.
  ruleBased,

  /// LLM extraction only.
  llmBased,

  /// Rules + LLM for low-confidence.
  hybrid,
}

/// Sentence segment with extraction metadata.
class SentenceSegment {
  /// Sentence text.
  final String text;

  /// Position in original content.
  final int position;

  /// Index in sentence list.
  final int index;

  /// Matched patterns.
  final List<String> matchedPatterns = [];

  SentenceSegment({
    required this.text,
    required this.position,
    required this.index,
  });
}
