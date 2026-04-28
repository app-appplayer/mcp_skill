import 'package:test/test.dart';
import 'package:mcp_skill/src/ports/skill_ports.dart';

void main() {
  group('SkillPorts', () {
    test('constructor sets required fields and leaves optionals null', () {
      final llm = StubLlmPort();
      const mcp = StubMcpPort();
      final ports = SkillPorts(llm: llm, mcp: mcp);

      expect(ports.llm, llm);
      expect(ports.mcp, mcp);
      expect(ports.facts, isNull);
      expect(ports.claims, isNull);
      expect(ports.runs, isNull);
      expect(ports.contextBundle, isNull);
      expect(ports.retrieval, isNull);
      expect(ports.asset, isNull);
    });

    test('constructor wires optional capability ports when provided', () {
      final llm = StubLlmPort();
      const mcp = StubMcpPort();
      const facts = StubFactsPort();
      const claims = StubClaimsPort();
      const runs = StubRunsPort();
      const contextBundle = StubContextBundlePort();
      const retrieval = StubRetrievalPort();
      const asset = StubAssetPort();

      final ports = SkillPorts(
        llm: llm,
        mcp: mcp,
        facts: facts,
        claims: claims,
        runs: runs,
        contextBundle: contextBundle,
        retrieval: retrieval,
        asset: asset,
      );

      expect(ports.facts, same(facts));
      expect(ports.claims, same(claims));
      expect(ports.runs, same(runs));
      expect(ports.contextBundle, same(contextBundle));
      expect(ports.retrieval, same(retrieval));
      expect(ports.asset, same(asset));
    });

    group('stub()', () {
      test('wires every capability port to its stub implementation', () {
        final ports = SkillPorts.stub();
        expect(ports.llm, isA<StubLlmPort>());
        expect(ports.mcp, isA<StubMcpPort>());
        expect(ports.facts, isA<StubFactsPort>());
        expect(ports.claims, isA<StubClaimsPort>());
        expect(ports.runs, isA<StubRunsPort>());
        expect(ports.contextBundle, isA<StubContextBundlePort>());
        expect(ports.retrieval, isA<StubRetrievalPort>());
        expect(ports.asset, isA<StubAssetPort>());
      });
    });

    group('copyWith()', () {
      test('returns copy with same ports when no overrides', () {
        final original = SkillPorts.stub();
        final copy = original.copyWith();
        expect(copy.llm, original.llm);
        expect(copy.mcp, original.mcp);
        expect(copy.facts, original.facts);
        expect(copy.claims, original.claims);
        expect(copy.runs, original.runs);
        expect(copy.contextBundle, original.contextBundle);
        expect(copy.retrieval, original.retrieval);
        expect(copy.asset, original.asset);
      });

      test('replaces llm when provided', () {
        final original = SkillPorts.stub();
        final newLlm = StubLlmPort();
        final copy = original.copyWith(llm: newLlm);
        expect(copy.llm, same(newLlm));
        expect(copy.mcp, same(original.mcp));
      });

      test('replaces mcp when provided', () {
        final original = SkillPorts.stub();
        const newMcp = StubMcpPort();
        final copy = original.copyWith(mcp: newMcp);
        expect(copy.mcp, same(newMcp));
        expect(copy.llm, same(original.llm));
      });

      test('replaces facts when provided', () {
        final original = SkillPorts.stub();
        const newFacts = StubFactsPort();
        final copy = original.copyWith(facts: newFacts);
        expect(copy.facts, same(newFacts));
      });

      test('replaces retrieval when provided', () {
        final original = SkillPorts.stub();
        const newRetrieval = StubRetrievalPort();
        final copy = original.copyWith(retrieval: newRetrieval);
        expect(copy.retrieval, same(newRetrieval));
      });
    });
  });
}
