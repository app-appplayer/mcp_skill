import 'package:test/test.dart';
import 'package:mcp_skill/src/exceptions/port_exceptions.dart';
import 'package:mcp_skill/src/exceptions/skill_exception.dart';

void main() {
  group('PortException', () {
    test('stores portName and message', () {
      final ex = PortException('llm', 'connection failed');
      expect(ex.portName, 'llm');
      expect(ex.message, 'connection failed');
      expect(ex.code, 'PORT_ERROR');
    });

    test('accepts optional cause and stackTrace', () {
      final cause = Exception('inner');
      final trace = StackTrace.current;
      final ex = PortException('mcp', 'fail', cause: cause, stackTrace: trace);
      expect(ex.cause, same(cause));
      expect(ex.stackTrace, same(trace));
    });

    test('extends SkillException', () {
      expect(PortException('p', 'm'), isA<SkillException>());
    });
  });

  group('LlmPortException', () {
    test('sets portName to llm', () {
      final ex = LlmPortException('model error');
      expect(ex.portName, 'llm');
      expect(ex.message, 'model error');
    });

    test('overrides code to LLM_PORT_ERROR', () {
      expect(LlmPortException('m').code, 'LLM_PORT_ERROR');
    });

    test('stores statusCode', () {
      final ex = LlmPortException('rate limited', statusCode: 429);
      expect(ex.statusCode, 429);
    });

    test('isRetryable is true when statusCode is null', () {
      final ex = LlmPortException('unknown error');
      expect(ex.isRetryable, isTrue);
    });

    test('isRetryable is true when statusCode is 429', () {
      final ex = LlmPortException('rate limited', statusCode: 429);
      expect(ex.isRetryable, isTrue);
    });

    test('isRetryable is true when statusCode >= 500', () {
      final ex500 = LlmPortException('server error', statusCode: 500);
      expect(ex500.isRetryable, isTrue);

      final ex503 = LlmPortException('unavailable', statusCode: 503);
      expect(ex503.isRetryable, isTrue);
    });

    test('isRetryable is false for client errors (4xx except 429)', () {
      final ex400 = LlmPortException('bad request', statusCode: 400);
      expect(ex400.isRetryable, isFalse);

      final ex401 = LlmPortException('unauthorized', statusCode: 401);
      expect(ex401.isRetryable, isFalse);

      final ex404 = LlmPortException('not found', statusCode: 404);
      expect(ex404.isRetryable, isFalse);
    });

    test('retryDelay is 30s for 429', () {
      final ex = LlmPortException('m', statusCode: 429);
      expect(ex.retryDelay, const Duration(seconds: 30));
    });

    test('retryDelay is 5s for 5xx', () {
      final ex = LlmPortException('m', statusCode: 500);
      expect(ex.retryDelay, const Duration(seconds: 5));

      final ex502 = LlmPortException('m', statusCode: 502);
      expect(ex502.retryDelay, const Duration(seconds: 5));
    });

    test('retryDelay is 1s when statusCode is null', () {
      final ex = LlmPortException('m');
      expect(ex.retryDelay, const Duration(seconds: 1));
    });

    test('accepts optional cause', () {
      final cause = Exception('root');
      final ex = LlmPortException('m', cause: cause);
      expect(ex.cause, same(cause));
    });

    test('extends PortException', () {
      expect(LlmPortException('m'), isA<PortException>());
    });
  });

  group('McpPortException', () {
    test('sets portName to mcp', () {
      final ex = McpPortException('tool error');
      expect(ex.portName, 'mcp');
      expect(ex.message, 'tool error');
    });

    test('overrides code to MCP_PORT_ERROR', () {
      expect(McpPortException('m').code, 'MCP_PORT_ERROR');
    });

    test('stores optional toolName', () {
      final ex = McpPortException('fail', toolName: 'web_search');
      expect(ex.toolName, 'web_search');
    });

    test('isRetryable is true', () {
      expect(McpPortException('m').isRetryable, isTrue);
    });

    test('retryDelay is 2 seconds', () {
      expect(McpPortException('m').retryDelay, const Duration(seconds: 2));
    });

    test('accepts optional cause', () {
      final cause = Exception('e');
      final ex = McpPortException('m', cause: cause);
      expect(ex.cause, same(cause));
    });

    test('extends PortException', () {
      expect(McpPortException('m'), isA<PortException>());
    });
  });

  group('KnowledgePortException', () {
    test('sets portName to knowledge', () {
      final ex = KnowledgePortException('retrieval error');
      expect(ex.portName, 'knowledge');
      expect(ex.message, 'retrieval error');
    });

    test('overrides code to KNOWLEDGE_PORT_ERROR', () {
      expect(KnowledgePortException('m').code, 'KNOWLEDGE_PORT_ERROR');
    });

    test('stores optional retrieverId', () {
      final ex = KnowledgePortException('fail', retrieverId: 'main-retriever');
      expect(ex.retrieverId, 'main-retriever');
    });

    test('isRetryable is true', () {
      expect(KnowledgePortException('m').isRetryable, isTrue);
    });

    test('retryDelay is 2 seconds', () {
      expect(
        KnowledgePortException('m').retryDelay,
        const Duration(seconds: 2),
      );
    });

    test('extends PortException', () {
      expect(KnowledgePortException('m'), isA<PortException>());
    });
  });

  group('FactGraphPortException', () {
    test('sets portName to factGraph', () {
      final ex = FactGraphPortException('graph error');
      expect(ex.portName, 'factGraph');
      expect(ex.message, 'graph error');
    });

    test('overrides code to FACTGRAPH_PORT_ERROR', () {
      expect(FactGraphPortException('m').code, 'FACTGRAPH_PORT_ERROR');
    });

    test('isRetryable is true', () {
      expect(FactGraphPortException('m').isRetryable, isTrue);
    });

    test('retryDelay is 1 second', () {
      expect(
        FactGraphPortException('m').retryDelay,
        const Duration(seconds: 1),
      );
    });

    test('accepts optional cause', () {
      final cause = Exception('e');
      final ex = FactGraphPortException('m', cause: cause);
      expect(ex.cause, same(cause));
    });

    test('extends PortException', () {
      expect(FactGraphPortException('m'), isA<PortException>());
    });
  });

  group('AssetNotFoundException', () {
    test('stores assetId and generates message', () {
      final ex = AssetNotFoundException('asset-123');
      expect(ex.assetId, 'asset-123');
      expect(ex.message, 'Asset not found: asset-123');
    });

    test('overrides code to ASSET_NOT_FOUND', () {
      expect(AssetNotFoundException('a').code, 'ASSET_NOT_FOUND');
    });

    test('isRetryable is false', () {
      expect(AssetNotFoundException('a').isRetryable, isFalse);
    });

    test('extends KnowledgePortException', () {
      expect(AssetNotFoundException('a'), isA<KnowledgePortException>());
    });
  });

  group('RetrieverNotFoundException', () {
    test('generates message from retrieverId', () {
      final ex = RetrieverNotFoundException('main-retriever');
      expect(ex.message, 'Retriever not found: main-retriever');
      expect(ex.retrieverId, 'main-retriever');
    });

    test('overrides code to RETRIEVER_NOT_FOUND', () {
      expect(RetrieverNotFoundException('r').code, 'RETRIEVER_NOT_FOUND');
    });

    test('isRetryable is false', () {
      expect(RetrieverNotFoundException('r').isRetryable, isFalse);
    });

    test('extends KnowledgePortException', () {
      expect(RetrieverNotFoundException('r'), isA<KnowledgePortException>());
    });
  });
}
