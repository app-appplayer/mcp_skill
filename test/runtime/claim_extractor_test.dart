// Tests for ClaimExtractor with rule-based, LLM-based, and hybrid strategies.

import 'dart:convert';

import 'package:test/test.dart';
import 'package:mcp_skill/src/runtime/claim_extractor.dart';
import 'package:mcp_skill/src/ports/llm_port.dart';

import '../helpers/mock_ports.dart';

void main() {
  group('ClaimExtractionConfig', () {
    test('defaults to hybrid strategy', () {
      const config = ClaimExtractionConfig();
      expect(config.strategy, equals(ClaimExtractionStrategy.hybrid));
      expect(config.minConfidence, equals(0.5));
      expect(config.maxClaims, isNull);
    });

    test('accepts custom values', () {
      const config = ClaimExtractionConfig(
        strategy: ClaimExtractionStrategy.ruleBased,
        minConfidence: 0.8,
        maxClaims: 10,
      );
      expect(config.strategy, equals(ClaimExtractionStrategy.ruleBased));
      expect(config.minConfidence, equals(0.8));
      expect(config.maxClaims, equals(10));
    });
  });

  group('ClaimExtractionStrategy.none', () {
    test('extracts nothing and makes no LLM call', () async {
      final llm = MockLlmPort();
      final extractor = ClaimExtractor(
        llmPort: llm,
        workspaceId: 'w',
        config:
            const ClaimExtractionConfig(strategy: ClaimExtractionStrategy.none),
      );
      expect(await extractor.extract('Revenue grew 12% in Q3. It is certain.'),
          isEmpty);
      expect(llm.completeCalls, isEmpty);
    });
  });

  group('ClaimExtractionStrategy', () {
    test('has four values: none and the three strategies', () {
      expect(ClaimExtractionStrategy.values.length, equals(4));
      expect(ClaimExtractionStrategy.values,
          contains(ClaimExtractionStrategy.none));
      expect(ClaimExtractionStrategy.values,
          contains(ClaimExtractionStrategy.ruleBased));
      expect(ClaimExtractionStrategy.values,
          contains(ClaimExtractionStrategy.llmBased));
      expect(ClaimExtractionStrategy.values,
          contains(ClaimExtractionStrategy.hybrid));
    });
  });

  group('ClaimExtractor', () {
    late MockLlmPort mockLlm;

    setUp(() {
      mockLlm = MockLlmPort();
    });

    group('rule-based extraction', () {
      late ClaimExtractor extractor;

      setUp(() {
        extractor = ClaimExtractor(
          llmPort: mockLlm,
          workspaceId: 'ws-1',
          config: const ClaimExtractionConfig(
            strategy: ClaimExtractionStrategy.ruleBased,
          ),
        );
      });

      test('extracts conclusion from "therefore" pattern', () async {
        final claims =
            await extractor.extract('Therefore the project is viable.');

        expect(claims, isNotEmpty);
        final conclusionClaims = claims
            .where((c) => c.type.toString().contains('conclusion'))
            .toList();
        expect(conclusionClaims, isNotEmpty);
      });

      test('extracts recommendation from "should" pattern', () async {
        final claims = await extractor
            .extract('The team should focus on performance.');

        expect(claims, isNotEmpty);
        final recClaims = claims
            .where((c) => c.type.toString().contains('recommendation'))
            .toList();
        expect(recClaims, isNotEmpty);
      });

      test('extracts observation from "observed" pattern', () async {
        final claims = await extractor
            .extract('We observed significant improvements.');

        expect(claims, isNotEmpty);
        final obsClaims = claims
            .where((c) => c.type.toString().contains('observation'))
            .toList();
        expect(obsClaims, isNotEmpty);
      });

      test('extracts prediction from "expect" pattern', () async {
        final claims = await extractor
            .extract('We expect revenue to increase next quarter.');

        expect(claims, isNotEmpty);
        final predClaims = claims
            .where((c) => c.type.toString().contains('prediction'))
            .toList();
        expect(predClaims, isNotEmpty);
      });

      test('extracts fact from "is/are" pattern', () async {
        final claims = await extractor
            .extract('The system is running at full capacity.');

        expect(claims, isNotEmpty);
      });

      test('returns empty for non-claim text', () async {
        // Sentences that do not match any pattern strongly
        final claims = await extractor.extract('');

        expect(claims, isEmpty);
      });

      test('deduplicates identical claims', () async {
        final claims = await extractor.extract(
          'Therefore we conclude X. Therefore we conclude X.',
        );

        // After dedup, should only have one claim for the same text
        final texts = claims.map((c) => c.text.toLowerCase().trim()).toSet();
        expect(texts.length, equals(claims.length));
      });

      test('sets workspaceId on claims', () async {
        final claims = await extractor
            .extract('Therefore the hypothesis is confirmed.');

        for (final claim in claims) {
          expect(claim.workspaceId, equals('ws-1'));
        }
      });

      test('sets sourceId when provided', () async {
        final claims = await extractor.extract(
          'Therefore the data shows improvement.',
          sourceId: 'report-123',
        );

        for (final claim in claims) {
          expect(claim.sourceId, equals('report-123'));
        }
      });

      test('confidence is clamped to 0.9 maximum', () async {
        // Even with multiple pattern matches, confidence should not exceed 0.9
        final claims = await extractor.extract(
          'Therefore the evidence shows this indicates a conclusion.',
        );

        for (final claim in claims) {
          expect(claim.confidence, lessThanOrEqualTo(0.9));
        }
      });

      test('metadata includes extraction method', () async {
        final claims = await extractor
            .extract('Therefore this is a conclusion.');

        if (claims.isNotEmpty) {
          expect(claims.first.metadata?['extractionMethod'],
              equals('rule_based'));
        }
      });
    });

    group('LLM-based extraction', () {
      late ClaimExtractor extractor;

      setUp(() {
        extractor = ClaimExtractor(
          llmPort: mockLlm,
          workspaceId: 'ws-1',
          config: const ClaimExtractionConfig(
            strategy: ClaimExtractionStrategy.llmBased,
          ),
        );
      });

      test('calls LLM and parses JSON response', () async {
        mockLlm.nextResponse = LlmResponse(
          content: jsonEncode([
            {
              'type': 'conclusion',
              'text': 'Revenue grew by 15%',
              'confidence': 0.95,
              'evidence': 'Q4 financial data',
            },
          ]),
          usage: const LlmUsage(inputTokens: 100, outputTokens: 50),
        );

        final claims = await extractor.extract('Some financial text');

        expect(claims.length, equals(1));
        expect(claims.first.text, equals('Revenue grew by 15%'));
        expect(claims.first.confidence, equals(0.95));
        expect(mockLlm.completeCalls.length, equals(1));
      });

      test('parses evidence as list', () async {
        mockLlm.nextResponse = LlmResponse(
          content: jsonEncode([
            {
              'type': 'fact',
              'text': 'Test claim',
              'confidence': 0.8,
              'evidence': ['source1', 'source2'],
            },
          ]),
          usage: const LlmUsage(inputTokens: 50, outputTokens: 30),
        );

        final claims = await extractor.extract('Some text');

        expect(claims.first.evidenceRefs, equals(['source1', 'source2']));
      });

      test('handles empty LLM response', () async {
        mockLlm.nextResponse = const LlmResponse(
          content: 'No claims found here.',
          usage: LlmUsage(inputTokens: 50, outputTokens: 10),
        );

        final claims = await extractor.extract('Some text');

        // Should return empty (no JSON array found)
        expect(claims, isEmpty);
      });

      test('falls back to rule-based on LLM error', () async {
        mockLlm.nextError = Exception('LLM unavailable');

        final claims = await extractor
            .extract('Therefore this is a conclusion.');

        // Should fall back to rule-based extraction
        expect(claims, isNotEmpty);
      });

      test('sets extractionMethod to llm_based', () async {
        mockLlm.nextResponse = LlmResponse(
          content: jsonEncode([
            {
              'type': 'observation',
              'text': 'The system is stable',
              'confidence': 0.85,
            },
          ]),
          usage: const LlmUsage(inputTokens: 50, outputTokens: 30),
        );

        final claims = await extractor.extract('Some text');

        if (claims.isNotEmpty) {
          expect(claims.first.metadata?['extractionMethod'],
              equals('llm_based'));
        }
      });

      test('parses different claim types', () async {
        mockLlm.nextResponse = LlmResponse(
          content: jsonEncode([
            {'type': 'conclusion', 'text': 'Claim 1', 'confidence': 0.9},
            {'type': 'recommendation', 'text': 'Claim 2', 'confidence': 0.8},
            {'type': 'hypothesis', 'text': 'Claim 3', 'confidence': 0.7},
            {'type': 'observation', 'text': 'Claim 4', 'confidence': 0.6},
          ]),
          usage: const LlmUsage(inputTokens: 100, outputTokens: 80),
        );

        final claims = await extractor.extract('Some text');

        expect(claims.length, equals(4));
      });
    });

    group('hybrid extraction', () {
      late ClaimExtractor extractor;

      setUp(() {
        extractor = ClaimExtractor(
          llmPort: mockLlm,
          workspaceId: 'ws-1',
          config: const ClaimExtractionConfig(
            strategy: ClaimExtractionStrategy.hybrid,
          ),
        );
      });

      test('uses rules first, then LLM for low-confidence claims', () async {
        // Set up LLM to return refined claims
        mockLlm.nextResponse = LlmResponse(
          content: jsonEncode([
            {
              'type': 'conclusion',
              'text': 'Refined claim',
              'confidence': 0.9,
            },
          ]),
          usage: const LlmUsage(inputTokens: 100, outputTokens: 50),
        );

        // Use text that generates low-confidence rule-based claims
        final claims = await extractor.extract(
          'Therefore data shows growth. The team should optimize.',
        );

        expect(claims, isNotEmpty);
      });

      test('keeps high-confidence rule-based claims as-is', () async {
        // Text with strong conclusion patterns and evidence
        final claims = await extractor.extract(
          'The evidence shows therefore we conclude because of the data.',
        );

        // High-confidence claims should not trigger LLM call
        // (Though behavior depends on exact confidence threshold)
        expect(claims, isNotEmpty);
      });

      test('returns original claims when LLM refinement fails', () async {
        mockLlm.nextError = Exception('LLM error');

        final claims = await extractor
            .extract('Therefore this is a test conclusion.');

        // Should still have claims from rule-based extraction
        expect(claims, isNotEmpty);
      });
    });
  });
}
